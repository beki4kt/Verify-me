// backend-server/src/paymentSecurity.ts
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

// backend-server/src/demoVerification.ts
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
  const backend = env.CHEKMI_BACKEND_URL?.trim() || "";
  const fixtureMode = env.CHEKMI_ENV === "staging" && env.CHEKMI_VERIFIER_MODE === "fixtures";
  const ready = Boolean(env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY && env.CHEKMI_INTERNAL_LOOKUP_KEY?.trim() && /^https:\/\/[^/?#]+\/api$/.test(backend));
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
    const reply = (status, body) => new Response(JSON.stringify({ ...body, demo: true, illustrative: fixtureMode, requestId }), { status, headers });
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (req.method === "GET") return reply(ready ? 200 : 503, { status: ready ? "ready" : "not_ready", service: "chekmi-demo", version: "2026-10-15.1", allowance: 10 });
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
      const outgoing = fixtureMode ? { provider, ...input, expectedAmount: 250, receivingAccount: typeof body.receivingAccount === "string" && body.receivingAccount.trim() ? body.receivingAccount.trim() : "0911000099" } : { provider, ...input };
      const cap = Number(env.DEMO_DAILY_LIMIT || 100);
      const reservation = await rpc("reserve_demo_lookup", { p_token_hash: tokenHash, p_request_id: body.lookupId, p_fingerprint: await hash(JSON.stringify(outgoing)), p_daily_limit: Number.isInteger(cap) && cap > 0 && cap <= 1e4 ? cap : 100 });
      const remaining = reservation.remaining;
      if (reservation.state === "existing") return reply(200, { success: false, code: "DEMO_PENDING", error: "This demo check is still pending. Check its result shortly.", ...reservation.result, remaining });
      if (reservation.state !== "reserved") return reply(429, { success: false, remaining, code: reservation.state === "exhausted" ? "DEMO_LIMIT_REACHED" : "DEMO_LIMIT", error: reservation.state === "exhausted" ? "You have used your 10 free checks. Connect a business to continue." : reservation.state === "conflict" ? "This request ID was already used for another receipt." : "The demo has reached its daily capacity. Try again tomorrow." });
      let result;
      try {
        const upstream = await transport(`${backend}/internal/provider-lookup`, { method: "POST", headers: { "x-chekmi-lookup-key": env.CHEKMI_INTERNAL_LOOKUP_KEY.trim(), "Content-Type": "application/json" }, body: JSON.stringify(outgoing), signal: AbortSignal.timeout(3e4), redirect: "error" });
        const verified = await boundedJson(upstream);
        if (!upstream.ok || verified.ok !== true) {
          result = { success: false, error: upstream.status >= 500 ? "The provider could not be reached. Try again later." : String(verified.error || "The provider could not verify this reference.") };
        } else {
          const data = verified.data;
          if (!data || typeof data.reference !== "string" || typeof data.amount !== "number" || data.amount <= 0 || typeof data.currency !== "string" || typeof data.txnDate !== "string")
            result = { success: false, error: "The provider returned an incomplete receipt." };
          else result = { success: true, receipt: { provider, reference: data.reference, amount: data.amount, currency: data.currency, date: data.txnDate, receiverName: data.receiverName, receiverAccount: data.receiverAccount, ...fixtureMode ? { sample: true } : {} } };
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
export {
  createDemoVerificationHandler
};
Deno.serve(createDemoVerificationHandler(Deno.env.toObject()));
