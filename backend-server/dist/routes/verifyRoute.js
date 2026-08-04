"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyRouter = void 0;
const express_1 = require("express");
const verifier_1 = require("@creofam/verifier");
exports.verifyRouter = (0, express_1.Router)();
// ---------------------------------------------------------------------------
// Configuration (read from env, with sensible defaults for local dev).
//   VERIFIER_BASE_URL     – upstream verifier API base URL
//   VERIFIER_UPSTREAM_KEY – optional API key forwarded to the upstream
//   VERIFIER_TIMEOUT_MS   – upstream request timeout (default 20000)
//   VERIFY_API_KEY        – if set, clients must send a matching x-api-key
// ---------------------------------------------------------------------------
const UPSTREAM_BASE_URL = process.env.VERIFIER_BASE_URL || "https://verifyapi.leulzenebe.pro";
const UPSTREAM_API_KEY = process.env.VERIFIER_UPSTREAM_KEY || undefined;
const UPSTREAM_TIMEOUT_MS = Number(process.env.VERIFIER_TIMEOUT_MS) || 20000;
const SERVER_API_KEY = process.env.VERIFY_API_KEY || undefined;
const verifier = new verifier_1.VerifierClient({
    baseUrl: UPSTREAM_BASE_URL,
    apiKey: UPSTREAM_API_KEY,
    timeoutMs: UPSTREAM_TIMEOUT_MS,
});
// ---------------------------------------------------------------------------
// Types & helpers
// ---------------------------------------------------------------------------
const KNOWN_PROVIDERS = [
    "telebirr",
    "cbe",
    "cbebirr",
    "dashen",
    "abyssinia",
    "mpesa",
];
function isProvider(v) {
    return typeof v === "string" && KNOWN_PROVIDERS.includes(v);
}
class ClientError extends Error {
    constructor(message, status, code = "CLIENT_ERROR") {
        super(message);
        this.status = status;
        this.code = code;
    }
}
// ---------------------------------------------------------------------------
// Optional API-key gate (only enforced when VERIFY_API_KEY is set, so local
// dev is unguarded but production can lock the endpoint down).
// ---------------------------------------------------------------------------
exports.verifyRouter.use((req, res, next) => {
    if (!SERVER_API_KEY)
        return next();
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
async function dispatch(provider, body) {
    const reference = (body.reference ?? "").trim();
    switch (provider) {
        case "telebirr":
            return (await verifier.verifyTelebirr({ reference }));
        case "cbe": {
            const suffix = (body.suffix ?? "").trim();
            if (!suffix)
                throw new ClientError("CBE verification requires an account 'suffix'.", 400, "MISSING_SUFFIX");
            return (await verifier.verifyCBE({ reference, accountSuffix: suffix }));
        }
        case "cbebirr":
            return (await verifier.verifyCBEBirr({ reference }));
        case "dashen":
            return (await verifier.verifyDashen({ reference }));
        case "abyssinia": {
            const suffix = (body.suffix ?? "").trim();
            if (!suffix)
                throw new ClientError("Abyssinia verification requires a 'suffix'.", 400, "MISSING_SUFFIX");
            return (await verifier.verifyAbyssinia({ reference, suffix }));
        }
        case "mpesa": {
            const receipt = (body.receiptNumber ?? body.reference ?? "").trim();
            if (!receipt)
                throw new ClientError("M-Pesa verification requires a 'receiptNumber'.", 400, "MISSING_RECEIPT");
            return (await verifier.verifyMpesa({ receiptNumber: receipt }));
        }
        default:
            // Exhaustiveness guard – should never be reached.
            throw new ClientError(`Unsupported provider: ${provider}`, 400, "INVALID_PROVIDER");
    }
}
// ---------------------------------------------------------------------------
// Shared handler – used by both the canonical route and the per-provider alias.
// ---------------------------------------------------------------------------
async function handleVerify(req, res) {
    const body = (req.body ?? {});
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
        const provider = providerRaw;
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
        const expected = typeof expectedRaw === "number" ? expectedRaw : Number(expectedRaw ?? NaN);
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
    }
    catch (err) {
        if (err instanceof ClientError) {
            res.status(err.status).json({ success: false, error: err.message, code: err.code });
            return;
        }
        if (err instanceof verifier_1.RateLimitError) {
            res.status(429).json({ success: false, error: "Upstream rate limit exceeded. Try again shortly.", code: "RATE_LIMIT" });
            return;
        }
        if (err instanceof verifier_1.VerifierError) {
            res.status(502).json({ success: false, error: "Verification failed: " + err.message, code: "VERIFIER_ERROR" });
            return;
        }
        console.error("[verify] unexpected error:", err);
        res.status(500).json({ success: false, error: "Internal server error", code: "INTERNAL_ERROR" });
    }
}
// Canonical endpoint: { provider, reference, suffix?, ... } in the body.
exports.verifyRouter.post("/verify", handleVerify);
// Per-provider alias:  POST /verify/telebirr  etc.
// Keeps the existing Flutter client working (it calls /verify/telebirr).
exports.verifyRouter.post("/verify/:provider", handleVerify);
//# sourceMappingURL=verifyRoute.js.map