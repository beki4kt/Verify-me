import { Router, Request, Response } from "express";
import {
  VerifierClient,
  VerifierError,
  RateLimitError,
  type Provider,
} from "@creofam/verifier";

export const verifyRouter = Router();

// ---------------------------------------------------------------------------
// Configuration (read from env, with sensible defaults for local dev).
//   VERIFIER_BASE_URL     – upstream verifier API base URL
//   VERIFIER_UPSTREAM_KEY – optional API key forwarded to the upstream
//   VERIFIER_TIMEOUT_MS   – upstream request timeout (default 20000)
//   VERIFY_API_KEY        – if set, clients must send a matching x-api-key
// ---------------------------------------------------------------------------
const UPSTREAM_BASE_URL =
  process.env.VERIFIER_BASE_URL || "https://verifyapi.leulzenebe.pro";
const UPSTREAM_API_KEY = process.env.VERIFIER_UPSTREAM_KEY || undefined;
const UPSTREAM_TIMEOUT_MS = Number(process.env.VERIFIER_TIMEOUT_MS) || 20000;
const SERVER_API_KEY = process.env.VERIFY_API_KEY || undefined;

const verifier = new VerifierClient({
  baseUrl: UPSTREAM_BASE_URL,
  apiKey: UPSTREAM_API_KEY,
  timeoutMs: UPSTREAM_TIMEOUT_MS,
});

// ---------------------------------------------------------------------------
// Types & helpers
// ---------------------------------------------------------------------------
const KNOWN_PROVIDERS: Provider[] = [
  "telebirr",
  "cbe",
  "cbebirr",
  "dashen",
  "abyssinia",
  "mpesa",
];

function isProvider(v: unknown): v is Provider {
  return typeof v === "string" && (KNOWN_PROVIDERS as string[]).includes(v);
}

class ClientError extends Error {
  status: number;
  code: string;
  constructor(message: string, status: number, code = "CLIENT_ERROR") {
    super(message);
    this.status = status;
    this.code = code;
  }
}

interface VerifyBody {
  provider?: string;
  reference?: string;
  suffix?: string;
  phoneNumber?: string;
  receiptNumber?: string;
  expectedAmount?: number | string;
}

// Minimal structural view of a normalized verification result.
interface NormResult {
  ok: boolean;
  provider?: Provider;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  data?: any;
  error?: string;
}

// ---------------------------------------------------------------------------
// Optional API-key gate (only enforced when VERIFY_API_KEY is set, so local
// dev is unguarded but production can lock the endpoint down).
// ---------------------------------------------------------------------------
verifyRouter.use((req: Request, res: Response, next) => {
  if (!SERVER_API_KEY) return next();
  const key = req.header("x-api-key");
  if (key !== SERVER_API_KEY) {
    return res
      .status(401)
      .json({ success: false, error: "Unauthorized: missing or invalid x-api-key", code: "UNAUTHORIZED" });
  }
  next();
});

// ---------------------------------------------------------------------------
// Dispatch to the correct per-provider SDK method.
// ---------------------------------------------------------------------------
async function dispatch(provider: Provider, body: VerifyBody): Promise<NormResult> {
  const reference = (body.reference ?? "").trim();
  switch (provider) {
    case "telebirr":
      return (await verifier.verifyTelebirr({ reference })) as unknown as NormResult;
    case "cbe": {
      const suffix = (body.suffix ?? "").trim();
      if (!suffix)
        throw new ClientError("CBE verification requires an account 'suffix'.", 400, "MISSING_SUFFIX");
      return (await verifier.verifyCBE({ reference, accountSuffix: suffix })) as unknown as NormResult;
    }
    case "cbebirr":
      return (await verifier.verifyCBEBirr({ reference })) as unknown as NormResult;
    case "dashen":
      return (await verifier.verifyDashen({ reference })) as unknown as NormResult;
    case "abyssinia": {
      const suffix = (body.suffix ?? "").trim();
      if (!suffix)
        throw new ClientError("Abyssinia verification requires a 'suffix'.", 400, "MISSING_SUFFIX");
      return (await verifier.verifyAbyssinia({ reference, suffix })) as unknown as NormResult;
    }
    case "mpesa": {
      const receipt = (body.receiptNumber ?? body.reference ?? "").trim();
      if (!receipt)
        throw new ClientError("M-Pesa verification requires a 'receiptNumber'.", 400, "MISSING_RECEIPT");
      return (await verifier.verifyMpesa({ receiptNumber: receipt })) as unknown as NormResult;
    }
    default:
      // Exhaustiveness guard – should never be reached.
      throw new ClientError(`Unsupported provider: ${provider}`, 400, "INVALID_PROVIDER");
  }
}

// ---------------------------------------------------------------------------
// Shared handler – used by both the canonical route and the per-provider alias.
// ---------------------------------------------------------------------------
async function handleVerify(req: Request, res: Response): Promise<void> {
  const body = (req.body ?? {}) as VerifyBody;
  const pathProvider = typeof req.params.provider === "string" ? req.params.provider : undefined;
  const providerRaw = body.provider || pathProvider || "";

  try {
    if (!isProvider(providerRaw)) {
      res.status(400).json({
        success: false,
        error: `Invalid provider. Must be one of: ${KNOWN_PROVIDERS.join(", ")}`,
        code: "INVALID_PROVIDER",
      });
      return;
    }

    const provider = providerRaw as Provider;
    const reference = (body.reference ?? "").trim();
    if (!reference && provider !== "mpesa") {
      res.status(400).json({ success: false, error: "Missing required field: reference", code: "INVALID_REFERENCE" });
      return;
    }
    if (provider === "mpesa" && !(body.receiptNumber || reference)) {
      res.status(400).json({ success: false, error: "Missing required field: receiptNumber", code: "INVALID_REFERENCE" });
      return;
    }

    const result = await dispatch(provider, body);

    // Upstream responded but the transaction could not be verified.
    if (!result.ok) {
      res.status(200).json({
        success: false,
        error: result.error || "Transaction could not be verified.",
        code: "NOT_VERIFIED",
        data: { verified: false, provider, reference: reference || undefined },
      });
      return;
    }

    const d = result.data ?? {};
    const amount = typeof d.amount === "number" ? d.amount : Number(d.amount ?? 0);
    const expectedRaw = body.expectedAmount;
    const expected =
      typeof expectedRaw === "number" ? expectedRaw : Number(expectedRaw ?? NaN);
    const underpayment = !Number.isNaN(expected) && amount < expected;

    res.status(200).json({
      success: true,
      data: {
        verified: true,
        provider,
        reference: d.reference ?? (reference || null),
        amount,
        totalAmount: typeof d.totalAmount === "number" ? d.totalAmount : null,
        currency: d.currency ?? "ETB",
        receiverAccount: d.receiverAccount ?? null,
        receiverName: d.receiverName ?? null,
        payerName: d.payerName ?? null,
        payerAccount: d.payerAccount ?? null,
        txnDate: d.txnDate ?? null,
        status: d.status ?? d.statusText ?? null,
        serviceFee: typeof d.serviceFee === "number" ? d.serviceFee : null,
        underpaymentDetected: underpayment,
        fraudDetected: underpayment,
      },
    });
  } catch (err) {
    if (err instanceof ClientError) {
      res.status(err.status).json({ success: false, error: err.message, code: err.code });
      return;
    }
    if (err instanceof RateLimitError) {
      res.status(429).json({ success: false, error: "Upstream rate limit exceeded. Try again shortly.", code: "RATE_LIMIT" });
      return;
    }
    if (err instanceof VerifierError) {
      res.status(502).json({ success: false, error: "Verification failed: " + err.message, code: "VERIFIER_ERROR" });
      return;
    }
    console.error("[verify] unexpected error:", err);
    res.status(500).json({ success: false, error: "Internal server error", code: "INTERNAL_ERROR" });
  }
}

// Canonical endpoint: { provider, reference, suffix?, ... } in the body.
verifyRouter.post("/verify", handleVerify);

// Per-provider alias:  POST /verify/telebirr  etc.
// Keeps the existing Flutter client working (it calls /verify/telebirr).
verifyRouter.post("/verify/:provider", handleVerify);
