"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyRouter = void 0;
const express_1 = require("express");
const verifier_1 = require("@creofam/verifier");
const paymentSecurity_1 = require("../paymentSecurity");
const supabaseRpc_1 = require("../supabaseRpc");
// Node 20.12+ can load local environment files without an extra dependency.
// The development server previously ignored `.env`, leaving the upstream key
// unset even though it was configured on disk.
process.loadEnvFile?.();
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
const TRANSACTION_MAX_AGE_MINUTES = Number(process.env.TRANSACTION_MAX_AGE_MINUTES) > 0
    ? Number(process.env.TRANSACTION_MAX_AGE_MINUTES)
    : 24 * 60;
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
async function findCommittedPayment(token, provider, reference) {
    return (0, supabaseRpc_1.callServiceRpc)("find_committed_payment", {
        p_token: token,
        p_provider: provider,
        p_transaction_ref: reference,
    });
}
async function recordFailedVerification(params) {
    try {
        await (0, supabaseRpc_1.callServiceRpc)("service_record_failed_verification", {
            p_token: params.token,
            p_provider: params.provider,
            p_transaction_ref: params.reference,
            p_expected_amount: params.expectedAmount,
            p_verified_amount: params.verifiedAmount ?? null,
            p_error_code: params.code,
            p_error_message: params.message,
        });
    }
    catch (error) {
        // A telemetry failure must not replace the original verification result.
        console.error("[verification-attempt] failed to record rejection:", error);
    }
}
async function rejectVerifiedPayment(res, params) {
    await recordFailedVerification(params);
    res.status(params.status).json({
        success: false,
        error: params.message,
        code: params.code,
    });
}
// ---------------------------------------------------------------------------
// Optional API-key gate (only enforced when VERIFY_API_KEY is set, so local
// dev is unguarded but production can lock the endpoint down).
// ---------------------------------------------------------------------------
exports.verifyRouter.use((req, res, next) => {
    // The production workflow authenticates with the opaque staff session.
    if (req.path === "/verify-and-create")
        return next();
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
            if (!/^\d{8}$/.test(suffix))
                throw new ClientError("CBE verification requires the last 8 account digits.", 400, "INVALID_SUFFIX");
            return (await verifier.verifyCBE({ reference, accountSuffix: suffix }));
        }
        case "cbebirr": {
            const phoneNumber = (body.phoneNumber ?? "").replace(/[\s()+-]/g, "").replace(/^0/, "251");
            if (!/^2519\d{8}$/.test(phoneNumber))
                throw new ClientError("CBE Birr requires a valid Ethiopian phone number.", 400, "INVALID_PHONE");
            return (await verifier.verifyUniversal({ reference, phoneNumber }));
        }
        case "dashen":
            return (await verifier.verifyDashen({ reference }));
        case "abyssinia": {
            const suffix = (body.suffix ?? "").trim();
            if (!/^\d{5}$/.test(suffix))
                throw new ClientError("Abyssinia verification requires a 5-digit suffix.", 400, "INVALID_SUFFIX");
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
        if (process.env.NODE_ENV === "production" &&
            process.env.ALLOW_LEGACY_VERIFY !== "true") {
            res.status(410).json({
                success: false,
                error: "Use the authenticated verify-and-create workflow.",
                code: "LEGACY_VERIFY_DISABLED",
            });
            return;
        }
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
        if (!Number.isFinite(expected) || expected <= 0) {
            res.status(400).json({ success: false, error: "A positive expectedAmount is required.", code: "INVALID_AMOUNT" });
            return;
        }
        if (!Number.isFinite(amount) || amount < 0) {
            res.status(502).json({ success: false, error: "Provider returned an invalid amount.", code: "INVALID_UPSTREAM_AMOUNT" });
            return;
        }
        const underpayment = amount + 0.001 < expected;
        if (underpayment) {
            res.status(422).json({
                success: false,
                error: `Transfer is ${amount} ETB; expected at least ${expected} ETB.`,
                code: "UNDERPAID",
                data: { verified: true, provider, reference: d.reference ?? reference, amount, expectedAmount: expected },
            });
            return;
        }
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
                expectedAmount: expected,
                tipAmount: Math.max(0, amount - expected),
                underpaymentDetected: false,
                fraudDetected: false,
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
            const raw = err.message || "";
            const upstreamUnavailable = raw.includes('cloudflare_error') || raw.includes('502') || raw.includes('Bad Gateway');
            if (upstreamUnavailable) {
                res.setHeader('Retry-After', '60');
                res.status(503).json({
                    success: false,
                    error: 'The bank verification service is temporarily unavailable. Please retry in about 60 seconds.',
                    code: 'VERIFIER_TEMPORARILY_UNAVAILABLE',
                    retryable: true,
                    retryAfterSeconds: 60,
                });
                return;
            }
            res.status(502).json({ success: false, error: "Verification failed: " + raw, code: "VERIFIER_ERROR" });
            return;
        }
        console.error("[verify] unexpected error:", err);
        res.status(500).json({ success: false, error: "Internal server error", code: "INTERNAL_ERROR" });
    }
}
async function handleVerifyAndCreate(req, res) {
    const body = (req.body ?? {});
    const providerRaw = body.provider || "";
    const expected = (0, paymentSecurity_1.positiveAmount)(body.expectedAmount);
    const reference = (body.reference ?? "").trim().toUpperCase();
    const tableNumber = (body.tableNumber ?? "").trim();
    const token = req.header("authorization")?.replace(/^Bearer\s+/i, "").trim();
    let provider = null;
    let verificationContextLoaded = false;
    try {
        if (!token || token.length < 32) {
            throw new ClientError("Staff session is required.", 401, "SESSION_REQUIRED");
        }
        if (!isProvider(providerRaw)) {
            throw new ClientError(`Invalid provider. Must be one of: ${KNOWN_PROVIDERS.join(", ")}`, 400, "INVALID_PROVIDER");
        }
        if (!reference || !tableNumber || expected === null) {
            throw new ClientError("Reference, table number, and a positive expected amount are required.", 400, "INVALID_TICKET");
        }
        if (body.receiptImageBase64 &&
            Buffer.byteLength(body.receiptImageBase64, "base64") > 1500000) {
            throw new ClientError("Compressed receipt image exceeds 1.5 MB.", 413, "RECEIPT_TOO_LARGE");
        }
        provider = providerRaw;
        const context = await (0, supabaseRpc_1.callServiceRpc)("get_verification_context", { p_token: token, p_provider: provider });
        verificationContextLoaded = true;
        if (context.provider !== provider) {
            throw new ClientError("Payment provider mismatch.", 400, "PROVIDER_MISMATCH");
        }
        // A response may have been committed even when the phone timed out. Check
        // before calling the provider again so a retry returns the original ticket.
        const existing = await findCommittedPayment(token, provider, reference);
        if (existing) {
            res.status(200).json({
                success: true,
                data: { ...existing, recovered: true, alreadyVerified: true },
            });
            return;
        }
        let dispatchBody = body;
        let abyssiniaSuffix = null;
        if (provider === "abyssinia") {
            abyssiniaSuffix = (0, paymentSecurity_1.authoritativeAbyssiniaSuffix)(context.receiving_account);
            if (!abyssiniaSuffix) {
                await rejectVerifiedPayment(res, {
                    token,
                    provider,
                    reference,
                    expectedAmount: expected,
                    status: 422,
                    code: "RECEIVING_ACCOUNT_INVALID",
                    message: "The configured Abyssinia account cannot provide the required five-digit destination suffix.",
                });
                return;
            }
            // Ignore any client suffix. The upstream verification must be anchored
            // to the receiving account selected from this authenticated tenant.
            dispatchBody = { ...body, suffix: abyssiniaSuffix };
        }
        const result = await dispatch(provider, dispatchBody);
        if (!result.ok) {
            await rejectVerifiedPayment(res, {
                token,
                provider,
                reference,
                expectedAmount: expected,
                status: 422,
                code: "NOT_VERIFIED",
                message: result.error || "Transaction could not be verified.",
            });
            return;
        }
        const data = result.data ?? {};
        const verifiedAmount = (0, paymentSecurity_1.positiveAmount)(data.amount);
        if (verifiedAmount === null) {
            await rejectVerifiedPayment(res, {
                token,
                provider,
                reference,
                expectedAmount: expected,
                status: 502,
                code: "INVALID_UPSTREAM_AMOUNT",
                message: "Provider returned an invalid amount.",
            });
            return;
        }
        if (verifiedAmount + .001 < expected) {
            await rejectVerifiedPayment(res, {
                token,
                provider,
                reference,
                expectedAmount: expected,
                verifiedAmount,
                status: 422,
                code: "UNDERPAID",
                message: `Transfer is ${verifiedAmount} ETB; expected at least ${expected} ETB.`,
            });
            return;
        }
        let receiverAccount = String(data.receiverAccount ?? data.receiver_account ?? "").trim();
        if (provider === "abyssinia") {
            // Abyssinia proves the destination through the server-supplied query
            // suffix and omits receiverAccount from its normalized response.
            receiverAccount = context.receiving_account;
        }
        else if (!(0, paymentSecurity_1.matchesReceivingAccount)(context.receiving_account, receiverAccount)) {
            await rejectVerifiedPayment(res, {
                token,
                provider,
                reference,
                expectedAmount: expected,
                verifiedAmount,
                status: 422,
                code: "DESTINATION_MISMATCH",
                message: "Payment was not sent to this business account.",
            });
            return;
        }
        const providerDate = data.txnDate ?? data.transactionDate ?? null;
        const freshness = (0, paymentSecurity_1.validateTransactionFreshness)(providerDate, {
            maxAgeMinutes: TRANSACTION_MAX_AGE_MINUTES,
        });
        if (!freshness.ok) {
            await rejectVerifiedPayment(res, {
                token,
                provider,
                reference,
                expectedAmount: expected,
                verifiedAmount,
                status: 422,
                code: freshness.code,
                message: freshness.message,
            });
            return;
        }
        const providerPayload = {
            ...data,
            verificationRequest: { submittedReference: reference },
            ...(provider === "abyssinia"
                ? {
                    destinationProof: {
                        method: "server_configured_account_suffix",
                        suffixLength: abyssiniaSuffix?.length,
                    },
                }
                : {}),
        };
        const committed = await (0, supabaseRpc_1.callServiceRpc)("commit_verified_payment", {
            p_token: token,
            p_provider: provider,
            p_transaction_ref: String(data.reference ?? reference).toUpperCase(),
            p_table_number: tableNumber,
            p_expected_amount: expected,
            p_verified_amount: verifiedAmount,
            p_currency: String(data.currency ?? "ETB"),
            p_receiver_account: receiverAccount,
            p_receiver_name: data.receiverName ?? data.receiver_name ?? null,
            p_payer_account: data.payerAccount ?? data.payer_account ?? null,
            p_payer_name: data.payerName ?? data.payer_name ?? null,
            p_provider_transaction_at: freshness.transactionDate.toISOString(),
            p_provider_status: data.status ?? data.statusText ?? null,
            p_provider_payload: providerPayload,
            p_receipt_image_base64: body.receiptImageBase64 ?? null,
        });
        res.status(201).json({
            success: true,
            data: {
                ...committed,
                amount: verifiedAmount,
                expectedAmount: expected,
                tipAmount: Math.max(0, verifiedAmount - expected),
                currency: data.currency ?? "ETB",
            },
        });
    }
    catch (err) {
        if (err instanceof ClientError) {
            res.status(err.status).json({ success: false, error: err.message, code: err.code });
            return;
        }
        if (err instanceof supabaseRpc_1.SupabaseRpcError) {
            const duplicate = err.code === "23505" || err.message.includes("already verified");
            const unauthorized = err.code === "28000" || err.status === 401;
            if (duplicate && token && provider) {
                try {
                    const existing = await findCommittedPayment(token, provider, reference);
                    if (existing) {
                        res.status(200).json({
                            success: true,
                            data: { ...existing, recovered: true, alreadyVerified: true },
                        });
                        return;
                    }
                }
                catch (recoveryError) {
                    console.error("[verify-and-create] duplicate recovery failed:", recoveryError);
                }
            }
            res.status(duplicate ? 409 : unauthorized ? 401 : err.status >= 500 ? 503 : 400).json({
                success: false,
                error: duplicate ? "This payment reference was already verified." : err.message,
                code: duplicate ? "DUPLICATE_PAYMENT" : unauthorized ? "SESSION_EXPIRED" : err.code || "DATABASE_ERROR",
            });
            return;
        }
        if (err instanceof verifier_1.RateLimitError) {
            if (token && provider && verificationContextLoaded) {
                await recordFailedVerification({
                    token,
                    provider,
                    reference,
                    expectedAmount: expected,
                    code: "RATE_LIMIT",
                    message: "Verification rate limit reached.",
                });
            }
            res.status(429).json({ success: false, error: "Verification rate limit reached.", code: "RATE_LIMIT" });
            return;
        }
        if (err instanceof verifier_1.VerifierError) {
            if (token && provider && verificationContextLoaded) {
                await recordFailedVerification({
                    token,
                    provider,
                    reference,
                    expectedAmount: expected,
                    code: "VERIFIER_ERROR",
                    message: "Payment provider is temporarily unavailable.",
                });
            }
            res.status(502).json({ success: false, error: "Payment provider is temporarily unavailable.", code: "VERIFIER_ERROR" });
            return;
        }
        console.error("[verify-and-create] unexpected error:", err);
        res.status(500).json({ success: false, error: "Internal server error", code: "INTERNAL_ERROR" });
    }
}
// Canonical endpoint: { provider, reference, suffix?, ... } in the body.
exports.verifyRouter.post("/verify", handleVerify);
// Authenticated production workflow: verifies and commits an immutable ticket
// in one server-controlled operation.
exports.verifyRouter.post("/verify-and-create", handleVerifyAndCreate);
// Per-provider alias:  POST /verify/telebirr  etc.
// Keeps the existing Flutter client working (it calls /verify/telebirr).
exports.verifyRouter.post("/verify/:provider", handleVerify);
//# sourceMappingURL=verifyRoute.js.map