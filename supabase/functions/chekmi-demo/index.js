// src/receiptFormat.ts
function nonEmpty(value) {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text ? text : null;
}
function ethiopianLocalDate(value) {
  const text = nonEmpty(value);
  if (!text) return null;
  let match = text.match(
    /^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?$/
  );
  if (match) {
    const [, day, month, year, hour, minute, second = "00"] = match;
    return validIso(`${year}-${month}-${day}T${hour}:${minute}:${second}+03:00`);
  }
  match = text.match(
    /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})[, ]+\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$/i
  );
  if (match) {
    const [, year, month, day, rawHour, minute, second = "00", meridiem] = match;
    let hour = Number(rawHour);
    if (meridiem) {
      hour %= 12;
      if (meridiem.toUpperCase() === "PM") hour += 12;
    }
    return validIso(
      `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}T${String(hour).padStart(2, "0")}:${minute}:${second}+03:00`
    );
  }
  match = text.match(
    /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$/
  );
  if (match) {
    const [, year, month, day, hour, minute, second = "00"] = match;
    return validIso(`${year}-${month}-${day}T${hour}:${minute}:${second}+03:00`);
  }
  return validIso(text);
}
function validIso(value) {
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? null : date.toISOString();
}
function completedStatus(value) {
  const normalized = String(value ?? "").toLowerCase().replace(/[^a-z]+/g, " ").trim();
  return (/* @__PURE__ */ new Set([
    "success",
    "successful",
    "completed",
    "complete",
    "settled",
    "paid",
    "transaction successful",
    "transaction completed",
    "transaction completed successfully",
    "payment successful",
    "payment completed"
  ])).has(normalized);
}
function referencesMatch(left, right) {
  const normalize = (value) => String(value ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  const normalizedLeft = normalize(left);
  const normalizedRight = normalize(right);
  return Boolean(normalizedLeft && normalizedLeft === normalizedRight);
}
function safeRaw(raw) {
  const copy = { ...raw };
  delete copy.base64Data;
  delete copy.pdf;
  return copy;
}
var LEGACY_COMBINED_ID = /^(FT[A-Z0-9]{10})(\d{8})$/i;
var NEW_CBE_URL = /^https?:\/\/mbreciept\.cbe\.com\.et\/([A-Za-z0-9-]+)\/?$/i;
var NEW_CBE_TOKEN = /^[A-Za-z0-9-]{15,80}$/;
function extractNewCbeToken(input) {
  const trimmed = input.trim();
  const urlMatch = trimmed.match(NEW_CBE_URL);
  if (urlMatch) return urlMatch[1] ?? null;
  if (!trimmed.toUpperCase().startsWith("FT") && NEW_CBE_TOKEN.test(trimmed)) {
    return trimmed;
  }
  return null;
}
function extractLegacyCbeUrlData(input) {
  try {
    const url = new URL(input.trim());
    if (url.hostname.toLowerCase() !== "apps.cbe.com.et") return null;
    if (url.port && url.port !== "100") return null;
    const match = url.searchParams.get("id")?.trim().match(LEGACY_COMBINED_ID);
    if (!match) return null;
    return { reference: (match[1] ?? "").toUpperCase(), suffix: match[2] ?? "" };
  } catch {
    return null;
  }
}

// src/veritasProtocol.ts
var object = (value) => value !== null && typeof value === "object" && !Array.isArray(value) ? value : null;
function veritasRequest(provider, input) {
  let reference = (input.reference ?? input.receiptNumber ?? "").trim();
  if (provider === "cbe") reference = extractLegacyCbeUrlData(reference)?.reference ?? reference;
  if (provider !== "cbe" || !extractNewCbeToken(reference)) reference = reference.toUpperCase();
  const body = provider === "cbebirr" ? { receiptNumber: reference, phoneNumber: (input.phoneNumber ?? "").replace(/[\s()+-]/g, "").replace(/^0/, "251") } : { reference };
  if (provider === "cbe" && input.suffix) body.accountSuffix = input.suffix;
  if (provider === "abyssinia") body.suffix = input.suffix ?? "";
  return { path: `/verify-${provider}`, body, reference };
}
function field(raw, ...keys) {
  for (const key of keys) if (raw[key] !== null && raw[key] !== void 0) return raw[key];
  return null;
}
function money(value) {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value !== "string") return null;
  const text = value.trim().replace(/^(?:ETB|Birr)\s*/i, "").replace(/\s*(?:ETB|Birr)$/i, "").trim();
  if (!/^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$/.test(text)) return null;
  const amount = Number(text.replace(/,/g, ""));
  return Number.isFinite(amount) ? amount : null;
}
function normalizeVeritas(provider, submitted, payload) {
  const fail = (error) => ({ ok: false, provider, error, code: "NOT_VERIFIED" });
  let raw = object(payload);
  if (!raw) return fail("Veritas returned an invalid receipt response.");
  let explicitSuccess = false;
  for (let depth = 0; depth < 4; depth++) {
    if (raw.success === false || raw.verified === false || raw.ok === false || raw.error) {
      return fail("Veritas could not verify this transaction. Check the reference and provider.");
    }
    explicitSuccess ||= raw.success === true || raw.verified === true;
    const nested = object(raw.data);
    if (!nested) break;
    raw = nested;
  }
  const header = object(raw.header);
  if (header) {
    if (!completedStatus(header.status)) return fail("Veritas returned an unsuccessful bank response.");
    const row = Array.isArray(raw.body) ? object(raw.body[0]) : null;
    if (!row) return fail("Veritas returned no receipt details.");
    raw = row;
    explicitSuccess = true;
  }
  const reference = nonEmpty(provider === "cbebirr" ? raw.receiptNumber : provider === "mpesa" ? field(raw, "transactionId", "receiptNo", "receiptNumber") : field(raw, "reference", "receiptNo", "receiptNumber", "transactionReference", "id", "Transaction Reference", "Payment Reference"));
  const amount = money(field(raw, "settledAmount", "transferredAmount", "transactionAmount", "amountCredited", "amount", "Transferred Amount"));
  const dateTimes = Array.isArray(raw.dateTimes) ? raw.dateTimes : [];
  const txnDate = ethiopianLocalDate(field(raw, "txnDate", "paymentDate", "transactionDate", "date", "Transaction Date") ?? dateTimes[0]);
  const status = nonEmpty(field(raw, "transactionStatus", "status", "statusText"));
  if (status && !completedStatus(status) || provider === "telebirr" && !completedStatus(status)) {
    return fail("The provider has not confirmed a completed payment.");
  }
  if (!explicitSuccess && !completedStatus(status)) return fail("Veritas did not confirm verification.");
  const lookupReference = provider === "cbe" ? extractLegacyCbeUrlData(submitted)?.reference ?? submitted : submitted;
  const matchesReference = referencesMatch(lookupReference, reference) || provider === "mpesa" && referencesMatch(lookupReference, raw.receiptNo);
  if (!reference || !(provider === "cbe" && extractNewCbeToken(lookupReference)) && !matchesReference) {
    return fail("The returned bank reference does not match this payment.");
  }
  if (amount === null || amount <= 0 || !txnDate) return fail("Veritas returned incomplete payment amount or date details.");
  const currency = nonEmpty(raw.currency)?.toUpperCase() ?? "ETB";
  if (currency !== "ETB" && currency !== "BIRR") return fail("This payment is not denominated in ETB.");
  return { ok: true, provider, data: {
    reference,
    amount,
    currency: "ETB",
    txnDate,
    status: "completed",
    statusText: status,
    receiverAccount: nonEmpty(field(raw, "receiverAccount", "receiverAccountNumber", "creditedPartyAccountNo", "creditAccount", "creditAccountNo", "phoneNo", "Receiver's Account", "Beneficiary Account")),
    receiverName: nonEmpty(field(raw, "receiverName", "receiver", "creditedPartyName", "creditAccountHolder", "Receiver's Name", "Beneficiary Name")),
    payerAccount: nonEmpty(field(raw, "payerAccount", "payerTelebirrNo", "senderAccountNumber", "senderAccount", "debitAccount", "debitAccountNo", "Source Account", "Payer's Account")),
    payerName: nonEmpty(field(raw, "payerName", "payer", "customerName", "senderName", "debitAccountHolder", "Payer's Name", "Source Account Name")),
    totalAmount: money(field(raw, "totalPaidAmount", "totalAmount", "total")),
    serviceFee: money(field(raw, "serviceFee", "serviceCharge")),
    raw: safeRaw(raw)
  } };
}

// src/paymentSecurity.ts
function normalizeAccount(value) {
  const normalized = String(value ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
  if (/^0[79]\d{8}$/.test(normalized)) return `251${normalized.slice(1)}`;
  if (/^[79]\d{8}$/.test(normalized)) return `251${normalized}`;
  return normalized;
}
function authoritativeAccountSuffix(configuredAccount, length) {
  if (!Number.isInteger(length) || length <= 0) return null;
  const digits = String(configuredAccount ?? "").replace(/\D/g, "");
  return digits.length >= length ? digits.slice(-length) : null;
}
function authoritativeEthiopianPhone(configuredAccount) {
  const normalized = normalizeAccount(configuredAccount);
  return /^251[79]\d{8}$/.test(normalized) ? normalized : null;
}

// src/demoVerification.ts
var providers = /* @__PURE__ */ new Set(["telebirr", "cbe", "cbebirr", "dashen", "abyssinia", "mpesa"]);
var hash = async (value) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)))).map((x) => x.toString(16).padStart(2, "0")).join("");
async function boundedJson(value, limit = 5e5) {
  const reader = value.body?.getReader();
  if (!reader) throw Error("Empty response");
  let size = 0;
  const chunks = [];
  while (true) {
    const { done, value: chunk } = await reader.read();
    if (done) break;
    size += chunk.length;
    if (size > limit) {
      await reader.cancel();
      throw Error("Response too large");
    }
    chunks.push(chunk);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  const result = JSON.parse(new TextDecoder().decode(bytes));
  if (!result || typeof result !== "object" || Array.isArray(result)) throw Error("Invalid JSON");
  return result;
}
function createDemoVerificationHandler(env, transport = fetch) {
  const ready = Boolean(env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY && env.VERITAS_API_KEY);
  return async (req) => {
    const requestId = crypto.randomUUID();
    const origin = req.headers.get("origin");
    const headers = { "Content-Type": "application/json", "Cache-Control": "no-store" };
    if (origin) {
      if (!(env.CORS_ALLOWED_ORIGINS || "").split(",").map((x) => x.trim()).includes(origin)) return new Response("Origin not allowed", { status: 403 });
      headers["Access-Control-Allow-Origin"] = origin;
      headers.Vary = "Origin";
      headers["Access-Control-Allow-Headers"] = "content-type,apikey";
      headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS";
    }
    const reply = (status, body) => new Response(JSON.stringify({ ...body, demo: true, requestId }), { status, headers });
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (req.method === "GET") return reply(ready ? 200 : 503, { status: ready ? "ready" : "not_ready", service: "chekmi-demo", version: "2026-09-08.1", allowance: 10 });
    if (req.method !== "POST") return reply(405, { success: false, error: "Use POST." });
    if (!ready) return reply(503, { success: false, code: "DEMO_NOT_CONFIGURED", error: "The demo scanner is not configured yet." });
    const rpc = async (name, params) => {
      const response = await transport(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, { method: "POST", headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json" }, body: JSON.stringify(params), signal: AbortSignal.timeout(8e3), redirect: "error" });
      if (!response.ok) throw Error("Demo database unavailable");
      return await response.json();
    };
    try {
      const body = await boundedJson(req, 4096);
      if (typeof body.installationToken !== "string" || !/^[0-9a-f]{64}$/.test(body.installationToken)) return reply(400, { success: false, error: "Invalid demo installation." });
      const tokenHash = await hash(body.installationToken);
      if (body.action === "usage" || body.action === "status") {
        if (body.action === "status" && !/^[0-9a-f-]{36}$/.test(body.lookupId || "")) return reply(400, { success: false, error: "Invalid demo request." });
        const state = await rpc("demo_lookup_status", { p_token_hash: tokenHash, p_request_id: body.action === "status" ? body.lookupId : null });
        return reply(200, { success: false, ...state, ...state.result || {}, remaining: state.remaining });
      }
      const provider = body.provider;
      const reference = typeof body.reference === "string" ? body.reference.trim() : "";
      if (body.action !== "verify" || !providers.has(provider) || !reference || reference.length > 256 || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(body.lookupId || "")) return reply(400, { success: false, error: "Select a payment method and enter its receipt reference." });
      const input = { reference };
      if (provider === "cbe" || provider === "abyssinia") {
        const suffix = authoritativeAccountSuffix(body.receivingAccount, provider === "cbe" ? 8 : 5);
        if (!suffix) return reply(400, { success: false, error: "Enter the receiving bank account shown on the receipt." });
        input.suffix = suffix;
      }
      if (provider === "cbebirr") {
        const phone = authoritativeEthiopianPhone(body.receivingAccount);
        if (!phone) return reply(400, { success: false, error: "Enter the receiving CBE Birr phone number." });
        input.phoneNumber = phone;
      }
      const outgoing = veritasRequest(provider, input);
      const cap = Number(env.DEMO_DAILY_LIMIT || 100);
      const reservation = await rpc("reserve_demo_lookup", { p_token_hash: tokenHash, p_request_id: body.lookupId, p_fingerprint: await hash(JSON.stringify({ provider, ...outgoing.body })), p_daily_limit: Number.isInteger(cap) && cap > 0 && cap <= 1e4 ? cap : 100 });
      const remaining = reservation.remaining;
      if (reservation.state === "existing") return reply(200, { success: false, code: "DEMO_PENDING", error: "This demo check is still pending. Check its result shortly.", ...reservation.result, remaining });
      if (reservation.state !== "reserved") return reply(429, { success: false, remaining, code: reservation.state === "exhausted" ? "DEMO_LIMIT_REACHED" : "DEMO_LIMIT", error: reservation.state === "exhausted" ? "You have used your 10 free checks. Connect a business to continue." : reservation.state === "conflict" ? "This request ID was already used for another receipt." : "The demo has reached its daily capacity. Try again tomorrow." });
      let result;
      try {
        const upstream = await transport(`https://verifyapi.leulzenebe.pro${outgoing.path}`, { method: "POST", headers: { "x-api-key": env.VERITAS_API_KEY.trim(), "Content-Type": "application/json" }, body: JSON.stringify(outgoing.body), signal: AbortSignal.timeout(25e3), redirect: "error" });
        if (!upstream.ok) {
          await upstream.body?.cancel();
          result = { success: false, error: upstream.status === 429 ? "The provider is busy. Try again later." : upstream.status >= 500 ? "The provider could not be reached. Try again later." : "The provider could not verify this reference." };
        } else {
          const normalized = normalizeVeritas(provider, outgoing.reference, await boundedJson(upstream));
          result = normalized.ok ? { success: true, receipt: { provider, reference: normalized.data.reference, amount: normalized.data.amount, currency: normalized.data.currency, date: normalized.data.txnDate, receiverName: normalized.data.receiverName, receiverAccount: normalized.data.receiverAccount } } : { success: false, error: normalized.error };
        }
      } catch {
        result = { success: false, error: "The provider did not respond in time. This lookup used one demo check." };
      }
      await rpc("finish_demo_lookup", { p_token_hash: tokenHash, p_request_id: body.lookupId, p_result: result });
      return reply(200, { ...result, remaining });
    } catch {
      return reply(503, { success: false, code: "DEMO_UNAVAILABLE", error: "Could not confirm the demo result. Check again before starting another lookup." });
    }
  };
}

// <stdin>
Deno.serve(createDemoVerificationHandler(Deno.env.toObject()));
