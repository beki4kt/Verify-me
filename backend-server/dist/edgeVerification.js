"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createEdgeVerificationHandler = createEdgeVerificationHandler;
const veritasProtocol_1 = require("./veritasProtocol");
const receiptFormat_1 = require("./receiptFormat");
const paymentSecurity_1 = require("./paymentSecurity");
const providers = new Set(["telebirr", "cbe", "cbebirr", "dashen", "abyssinia", "mpesa"]);
class Failure extends Error {
    constructor(code, message, status = 422, retryable = false) {
        super(message);
        this.code = code;
        this.status = status;
        this.retryable = retryable;
    }
}
function json(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value) ? value : null;
}
async function readJson(body, limit) {
    const reader = body.body?.getReader();
    if (!reader)
        return null;
    const chunks = [];
    let length = 0;
    while (true) {
        const { done, value } = await reader.read();
        if (done)
            break;
        length += value.length;
        if (length > limit) {
            await reader.cancel();
            throw new Failure("RESPONSE_TOO_LARGE", "The request or service response was too large.", 413);
        }
        chunks.push(value);
    }
    const buffer = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
        buffer.set(chunk, offset);
        offset += chunk.length;
    }
    try {
        return JSON.parse(new TextDecoder().decode(buffer));
    }
    catch {
        throw new Failure("INVALID_SERVICE_RESPONSE", "The payment service returned an invalid response.", 502, true);
    }
}
// Web-standard handler: the same code is exercised in Node tests and bundled
// without dependencies for Supabase's Deno runtime. No Alet request occurs here.
function createEdgeVerificationHandler(env, transport = fetch) {
    const limits = new Map();
    const inFlight = new Set();
    const configured = Boolean(env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY && env.VERITAS_API_KEY?.trim());
    return async (req) => {
        const requestId = crypto.randomUUID();
        const origin = req.headers.get("origin");
        const allowedOrigins = (env.CORS_ALLOWED_ORIGINS || "").split(",").map(x => x.trim());
        const originAllowed = !origin || allowedOrigins.includes(origin);
        const headers = { "Content-Type": "application/json", "Cache-Control": "no-store", "x-request-id": requestId };
        if (origin && originAllowed) {
            headers["Access-Control-Allow-Origin"] = origin;
            headers.Vary = "Origin";
            headers["Access-Control-Allow-Headers"] = "authorization, apikey, content-type, x-client-info";
            headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS";
        }
        const respond = (status, body) => new Response(JSON.stringify({ ...body, requestId }), { status, headers });
        if (!originAllowed)
            return respond(403, { success: false, code: "ORIGIN_NOT_ALLOWED", error: "This web origin is not configured." });
        if (req.method === "OPTIONS")
            return new Response(null, { status: 204, headers });
        if (req.method === "GET")
            return respond(configured ? 200 : 503, {
                status: configured ? "ready" : "not_ready", verifierMode: "live",
                verifier: { engine: "veritas", mode: "transaction-id", configured, imageVerification: false },
                service: "chekmi-verify", version: "2026-09-08.2",
            });
        if (req.method !== "POST")
            return respond(405, { success: false, code: "METHOD_NOT_ALLOWED", error: "Use POST." });
        const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim();
        if (!token || token.length < 32)
            return respond(401, { success: false, code: "SESSION_REQUIRED", error: "Sign in before verifying a payment." });
        if (!configured)
            return respond(503, { success: false, code: "VERITAS_NOT_CONFIGURED", error: "Payment verification is not configured. Ask the administrator to complete Supabase function setup." });
        const startedAt = Date.now();
        const deadline = AbortSignal.timeout(45000);
        let context = null;
        let provider;
        let reference = "";
        let canonicalReference = "";
        let expected = null;
        let lockKey = null;
        const rpc = async (name, params, timeout = 8000) => {
            let res;
            try {
                res = await transport(`${env.SUPABASE_URL.replace(/\/$/, "")}/rest/v1/rpc/${name}`, {
                    method: "POST", headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json" },
                    body: JSON.stringify(params), redirect: "error", signal: AbortSignal.any([deadline, AbortSignal.timeout(timeout)]),
                });
                const value = await readJson(res, 1000000);
                if (!res.ok) {
                    const detail = json(value);
                    const code = String(detail?.code ?? "DATABASE_ERROR");
                    if (code === "28000" || res.status === 401)
                        throw new Failure("SESSION_EXPIRED", "Your staff session expired. Sign in again.", 401);
                    if (code === "23505")
                        throw new Failure("DUPLICATE_PAYMENT", "This payment has already been verified.", 409);
                    if (code === "42501")
                        throw new Failure("ACCESS_DENIED", "This staff account is not allowed to verify payments.", 403);
                    throw new Failure(code, String(detail?.message ?? "The payment database is unavailable."), res.status >= 500 ? 503 : 400, res.status >= 500);
                }
                return value;
            }
            catch (e) {
                if (e instanceof Failure)
                    throw e;
                throw new Failure("DATABASE_UNAVAILABLE", "Could not confirm the saved payment. Check payment history before retrying.", 503, true);
            }
        };
        const find = () => rpc("find_committed_payment", { p_token: token, p_provider: provider, p_transaction_ref: canonicalReference || reference });
        try {
            const body = json(await readJson(req, 2100000));
            if (!body || typeof body.provider !== "string" || !providers.has(body.provider))
                throw new Failure("INVALID_PROVIDER", "Select a payment provider.", 400);
            provider = body.provider;
            const inputReference = typeof body.reference === "string" ? body.reference.trim() : "";
            if (!inputReference || inputReference.length > 256)
                throw new Failure("INVALID_REFERENCE", "Enter the bank transaction reference.", 400);
            reference = provider === "cbe" ? (0, receiptFormat_1.extractLegacyCbeUrlData)(inputReference)?.reference ?? inputReference : inputReference.toUpperCase();
            if (provider === "cbe" && !(0, receiptFormat_1.extractNewCbeToken)(reference))
                reference = reference.toUpperCase();
            const action = body.action ?? "verify";
            if (action !== "verify" && action !== "status")
                throw new Failure("INVALID_ACTION", "Unknown verification action.", 400);
            expected = (0, paymentSecurity_1.positiveAmount)(body.expectedAmount);
            const businessReference = typeof body.tableNumber === "string" ? body.tableNumber.trim() : "";
            if (action === "verify" && (expected === null || !businessReference || businessReference.length > 320))
                throw new Failure("INVALID_PAYMENT", "Enter a positive amount due and business reference.", 400);
            const photo = body.receiptImageBase64;
            if (photo !== undefined && (typeof photo !== "string" || !/^[A-Za-z0-9+/]*={0,2}$/.test(photo) || photo.length % 4 !== 0 || photo.length > 2000000))
                throw new Failure("RECEIPT_TOO_LARGE", "The receipt image is invalid or exceeds 1.5 MB.", 413);
            // The trusted RPC validates the opaque session and business scope. The
            // public Supabase publishable key is never sufficient authorization.
            context = json(await rpc("get_verification_context", { p_token: token, p_provider: provider }));
            if (!context || context.provider !== provider || !["waiter", "admin"].includes(String(context.role)) || !context.business_id || !context.receiving_account)
                throw new Failure("ACCESS_DENIED", "This account cannot verify payments for that business.", 403);
            const existing = json(await find());
            if (existing?.ticket_id)
                return respond(200, { success: true, data: { ...existing, recovered: true, alreadyVerified: true } });
            if (action === "status")
                return respond(200, { success: false, code: "NOT_COMMITTED", error: "No saved verified payment was found for this reference.", state: "not_confirmed" });
            const identity = `${context.business_id}:${context.staff_number}`;
            const now = Date.now();
            for (const [key, bucket] of limits)
                if (bucket.until <= now)
                    limits.delete(key);
            const bucket = limits.get(identity) ?? { count: 0, until: now + 60000 };
            bucket.count++;
            limits.set(identity, bucket);
            if (bucket.count > 20)
                throw new Failure("RATE_LIMIT", "Too many verification attempts. Wait a minute.", 429, true);
            lockKey = `${context.business_id}:${provider}:${reference}`;
            if (inFlight.has(lockKey)) {
                lockKey = null;
                throw new Failure("VERIFICATION_IN_PROGRESS", "This payment is being checked. Check its saved result shortly.", 409, true);
            }
            inFlight.add(lockKey);
            const account = String(context.receiving_account);
            const lookup = { reference };
            let suffixProof = false;
            if (provider === "cbe" || provider === "abyssinia") {
                const suffix = (0, paymentSecurity_1.authoritativeAccountSuffix)(account, provider === "cbe" ? 8 : 5);
                if (!suffix)
                    throw new Failure("RECEIVING_ACCOUNT_INVALID", "Update this business's receiving account in Admin.");
                lookup.suffix = suffix;
                suffixProof = provider === "abyssinia" || (0, receiptFormat_1.isLegacyCbeReference)(reference);
            }
            else if (provider === "cbebirr") {
                const phone = (0, paymentSecurity_1.authoritativeEthiopianPhone)(account);
                if (!phone)
                    throw new Failure("RECEIVING_ACCOUNT_INVALID", "Configure a valid CBE Birr receiving phone in Admin.");
                lookup.phoneNumber = phone;
            }
            const outgoing = (0, veritasProtocol_1.veritasRequest)(provider, lookup);
            let upstream;
            let payload;
            // One bounded retry of the read-only provider lookup absorbs short
            // outages. Never retry a database commit, invalid receipt, access/credit
            // error or rate limit. Each provider attempt can consume a Veritas credit.
            for (let attempt = 1; attempt <= 2; attempt++) {
                const timeout = Math.min(20000, 45000 - (Date.now() - startedAt) - 10000);
                if (timeout < 1000)
                    break; // Reserve time to validate and save a result.
                const attemptStart = Date.now();
                upstream = undefined;
                let failed = false;
                try {
                    upstream = await transport(`https://verifyapi.leulzenebe.pro${outgoing.path}`, {
                        method: "POST", headers: { "x-api-key": env.VERITAS_API_KEY.trim(), "Content-Type": "application/json", Accept: "application/json" },
                        body: JSON.stringify(outgoing.body), redirect: "error", signal: AbortSignal.any([deadline, AbortSignal.timeout(timeout)]),
                    });
                    // Check status before JSON parsing: a gateway may return an HTML
                    // access/credit/rate-limit error, which must keep its real category.
                    if ([500, 502, 503, 504].includes(upstream.status)) {
                        failed = true;
                        await upstream.body?.cancel();
                    }
                    else if (upstream.ok) {
                        payload = await readJson(upstream, 1000000);
                    }
                    else {
                        await upstream.body?.cancel();
                    }
                }
                catch {
                    failed = true;
                }
                // Structured operational evidence only: no key, token, account,
                // reference, receipt body or raw transport exception in logs.
                console.info(JSON.stringify({ event: "veritas_lookup", requestId, provider,
                    attempt, httpStatus: upstream?.status ?? null, elapsedMs: Date.now() - attemptStart,
                    outcome: failed ? "transient_failure" : "response" }));
                if (!failed)
                    break;
                upstream = undefined;
                if (attempt < 2 && !deadline.aborted)
                    await new Promise(resolve => setTimeout(resolve, 400));
            }
            if (!upstream)
                throw new Failure("VERITAS_UNAVAILABLE", "The payment provider did not respond after a second check. Keep this receipt and try again shortly; this attempt did not save a payment.", 503, true);
            if (upstream.status === 401 || upstream.status === 403)
                throw new Failure("VERITAS_ACCESS_DENIED", "The Veritas key or subscription access needs attention in Supabase function secrets.", 503);
            if (upstream.status === 402)
                throw new Failure("VERITAS_CREDITS_EXHAUSTED", "The Veritas verification credit balance is exhausted.", 503);
            if (upstream.status === 429)
                throw new Failure("VERITAS_RATE_LIMIT", "Veritas is rate limiting requests. Wait a minute.", 429, true);
            if (upstream.status >= 500)
                throw new Failure("VERITAS_UNAVAILABLE", "The payment provider is temporarily unavailable. Keep this receipt and try again shortly.", 503, true);
            if (!upstream.ok)
                throw new Failure("NOT_VERIFIED", "Veritas could not verify this reference.");
            const verified = (0, veritasProtocol_1.normalizeVeritas)(provider, reference, payload);
            if (!verified.ok)
                throw new Failure("NOT_VERIFIED", verified.error);
            const data = verified.data;
            if (data.amount + .001 < expected)
                throw new Failure("UNDERPAID", `Payment is ${data.amount} ETB; amount due is ${expected} ETB.`);
            const destinationMatches = provider === "cbe" ? (0, paymentSecurity_1.matchesCbeReceivingAccount)(account, data.receiverAccount)
                : provider === "telebirr" ? (0, paymentSecurity_1.matchesTelebirrReceivingAccount)(account, data.receiverAccount)
                    : (0, paymentSecurity_1.matchesReceivingAccount)(account, data.receiverAccount);
            // Suffix-bound lookups can omit/mask the account. A contradictory full
            // destination must still be rejected rather than overwritten.
            const returned = String(data.receiverAccount ?? "");
            const fullReturned = returned && !returned.includes("*");
            if ((!suffixProof && !destinationMatches) || (suffixProof && fullReturned && !destinationMatches))
                throw new Failure("DESTINATION_MISMATCH", "Payment was not sent to this business's configured account.");
            const freshness = (0, paymentSecurity_1.validateTransactionFreshness)(data.txnDate, { maxAgeMinutes: 1440 });
            if (!freshness.ok)
                throw new Failure(freshness.code, `${freshness.message} Receipt date: ${data.txnDate ?? "missing"}.`);
            canonicalReference = data.reference.toUpperCase();
            const committed = json(await rpc("commit_verified_payment", {
                p_token: token, p_provider: provider, p_transaction_ref: canonicalReference,
                p_table_number: businessReference, p_expected_amount: expected, p_verified_amount: data.amount,
                p_currency: data.currency, p_receiver_account: suffixProof ? account : data.receiverAccount,
                p_receiver_name: data.receiverName ?? null, p_payer_account: data.payerAccount ?? null, p_payer_name: data.payerName ?? null,
                p_provider_transaction_at: freshness.transactionDate.toISOString(), p_provider_status: data.status,
                p_provider_payload: { ...data, verificationRequest: { submittedReference: inputReference, engine: "veritas", host: "supabase-edge", method: "transaction-id" }, ...(suffixProof ? { destinationProof: { method: "server_configured_account_suffix" } } : {}) },
                p_receipt_image_base64: photo ?? null,
            }));
            if (!committed?.ticket_id)
                throw new Failure("COMMIT_NOT_CONFIRMED", "No saved payment confirmation was returned. Check payment history before retrying.", 503, true);
            return respond(201, { success: true, data: { ...committed, amount: data.amount, expectedAmount: expected, tipAmount: Math.max(0, data.amount - expected), currency: data.currency } });
        }
        catch (error) {
            const failure = error instanceof Failure ? error : new Failure("VERIFICATION_UNAVAILABLE", "Payment verification could not finish. Check payment history before retrying.", 503, true);
            if (failure.code === "DUPLICATE_PAYMENT") {
                try {
                    const existing = json(await find());
                    if (existing?.ticket_id)
                        return respond(200, { success: true, data: { ...existing, recovered: true, alreadyVerified: true } });
                }
                catch { /* Preserve the duplicate result. */ }
            }
            if (context && provider && failure.status === 422) {
                try {
                    await rpc("service_record_failed_verification", { p_token: token, p_provider: provider, p_transaction_ref: reference, p_expected_amount: expected, p_verified_amount: null, p_error_code: failure.code, p_error_message: failure.message }, 2000);
                }
                catch { /* Telemetry cannot replace the original rejection. */ }
            }
            return respond(failure.status, { success: false, code: failure.code, error: failure.message, retryable: failure.retryable, ...(failure.retryable ? { retryAfterSeconds: 60 } : {}) });
        }
        finally {
            if (lockKey)
                inFlight.delete(lockKey);
        }
    };
}
//# sourceMappingURL=edgeVerification.js.map