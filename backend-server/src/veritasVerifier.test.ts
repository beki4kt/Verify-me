import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";
import express from "express";
import { normalizeVeritas, veritasRequest, verifierConfiguration, verifyWithVeritas } from "./veritasVerifier";
import { OwnedVerifierError, type Provider } from "./ownedVerifier";

const receipt = (overrides = {}) => ({
  payerName: "Test Sender", payerTelebirrNo: "0911222333",
  creditedPartyName: "Test Business", creditedPartyAccountNo: "0911000099",
  transactionStatus: "Completed", receiptNo: "DHU5AM9UB3",
  paymentDate: new Date().toISOString(), settledAmount: "1,500.00 Birr",
  totalPaidAmount: "1,505.00 Birr", serviceFee: "5.00 Birr", ...overrides,
});

test("Veritas readiness requires a private key and safe URL; owned remains explicit fallback", () => {
  assert.equal(verifierConfiguration({ CHEKMI_VERIFICATION_ENGINE: "veritas" }).configured, false);
  assert.equal(verifierConfiguration({ CHEKMI_VERIFICATION_ENGINE: "veritas", VERITAS_API_KEY: "test" }).configured, true);
  assert.equal(verifierConfiguration({ CHEKMI_VERIFICATION_ENGINE: "veritas", VERITAS_API_KEY: "test", VERITAS_API_URL: "http://example.com" }).configured, false);
  assert.equal(verifierConfiguration({ CHEKMI_VERIFICATION_ENGINE: "typo" }).configured, false);
  assert.equal(verifierConfiguration({}).engine, "owned");
});

test("ID request whitelist excludes photos and preserves provider-specific fields", () => {
  const input = { reference: " tx12345678 ", suffix: "12345678", phoneNumber: "0911222333", receiptImageBase64: "must-not-leave-server", expectedAmount: 999 };
  assert.deepEqual(veritasRequest("telebirr", input).body, { reference: "TX12345678" });
  assert.deepEqual(veritasRequest("cbe", input).body, { reference: "TX12345678", accountSuffix: "12345678" });
  assert.deepEqual(veritasRequest("abyssinia", { ...input, suffix: "12345" }).body, { reference: "TX12345678", suffix: "12345" });
  assert.deepEqual(veritasRequest("cbebirr", input).body, { receiptNumber: "TX12345678", phoneNumber: "251911222333" });
  for (const provider of ["telebirr", "cbe", "abyssinia", "cbebirr", "dashen", "mpesa"] as Provider[]) {
    assert.equal(veritasRequest(provider, input).path, `/verify-${provider}`);
    assert.ok(!JSON.stringify(veritasRequest(provider, input)).includes("must-not-leave-server"));
  }
});

test("Telebirr maps the principal instead of total including fees", () => {
  const result = normalizeVeritas("telebirr", "DHU5AM9UB3", { success: true, data: receipt() });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.equal(result.data.amount, 1500);
    assert.equal(result.data.totalAmount, 1505);
    assert.equal(result.data.receiverAccount, "0911000099");
  }
});

test("nested provider failures, mismatched IDs, pending statuses and malformed money fail closed", () => {
  for (const payload of [
    { success: false, data: receipt() },
    { success: true, data: { success: false, data: receipt() } },
    { success: true, data: receipt({ receiptNo: "DIFFERENT" }) },
    { success: true, data: receipt({ transactionStatus: "Pending" }) },
    { success: true, data: receipt({ settledAmount: "error 1500" }) },
    { success: true, data: receipt({ settledAmount: null }) },
    { success: true, data: receipt({ paymentDate: null }) },
    { success: true, data: receipt({ currency: "USD" }) },
    { success: true, data: {} },
    "<html>Bad gateway</html>",
  ]) assert.equal(normalizeVeritas("telebirr", "DHU5AM9UB3", payload).ok, false);
});

test("bank envelopes normalize without borrowing submitted receipt fields", () => {
  const date = new Date().toISOString();
  const samples: [Provider, string, unknown][] = [
    ["cbe", "FT1234567890", { success: true, reference: "FT1234567890", amount: 1500, paymentDate: date, receiverAccount: "1000123456789" }],
    ["dashen", "1234567890123456", { success: true, transactionReference: "1234567890123456", transactionAmount: 1500, transactionDate: date, phoneNo: "0911000099" }],
    ["abyssinia", "FT1234567890", { success: true, data: { header: { status: "success" }, body: [{ "Transaction Reference": "FT1234567890", "Transferred Amount": "1500.00", "Transaction Date": date }] } }],
    ["cbebirr", "TX12345678", { customerName: "Test Sender", debitAccount: "0911222333", creditAccount: "0911000099", transactionStatus: "Completed", reference: "Purchase of supplies", receiptNumber: "TX12345678", amount: "1500.00", transactionDate: date }],
    ["mpesa", "TX12345678", { success: true, transactionId: "TX12345678", receiptNo: "OTHER12345", amount: 1500, paymentDate: date, receiverAccount: "0911000099" }],
  ];
  for (const [provider, reference, payload] of samples) assert.equal(normalizeVeritas(provider, reference, payload).ok, true, provider);
  assert.equal(normalizeVeritas("dashen", "1234567890123456", { success: true, transactionReference: "9999999999999999", transactionAmount: 1500, transactionDate: date }).ok, false);
});

test("authenticated ID verification enforces destination, amount, date, duplicate recovery and secret isolation", async () => {
  let status = 200;
  let payload: unknown = { success: true, data: receipt() };
  let calls = 0;
  let commits = 0;
  let existing = false;
  let committed: Record<string, unknown> = {};
  const upstream = createServer(async (req, res) => {
    calls++;
    assert.equal(req.url, "/verify-telebirr");
    assert.equal(req.headers["x-api-key"], "test-private-key");
    let body = "";
    for await (const chunk of req) body += chunk;
    assert.deepEqual(JSON.parse(body), { reference: "DHU5AM9UB3" });
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(payload));
  });
  const database = createServer(async (req, res) => {
    let text = "";
    for await (const chunk of req) text += chunk;
    const params = JSON.parse(text);
    res.setHeader("Content-Type", "application/json");
    switch (req.url?.split("/").pop()) {
      case "get_verification_context": res.end(JSON.stringify({ business_id: "test-business", staff_number: "01", role: "waiter", provider: "telebirr", receiving_account: "0911000099" })); break;
      case "find_committed_payment": res.end(JSON.stringify(existing ? { ticket_id: "ticket-one", reference: "DHU5AM9UB3" } : null)); break;
      case "commit_verified_payment": commits++; committed = params; res.end(JSON.stringify({ ticket_id: "ticket-one" })); break;
      case "service_record_failed_verification": res.end("null"); break;
      default: res.statusCode = 404; res.end("{}");
    }
  });
  for (const server of [upstream, database]) await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
  const address = (server: ReturnType<typeof createServer>) => { const a = server.address(); assert.ok(a && typeof a !== "string"); return `http://127.0.0.1:${a.port}`; };
  const env = { NODE_ENV: "test", CHEKMI_ENV: "development", CHEKMI_VERIFIER_MODE: "live", CHEKMI_VERIFICATION_ENGINE: "veritas", VERITAS_API_KEY: "test-private-key", VERITAS_API_URL: address(upstream), SUPABASE_URL: address(database), SUPABASE_SERVICE_ROLE_KEY: "test-database-key" };
  const previous = Object.fromEntries(Object.keys(env).map(key => [key, process.env[key]]));
  Object.assign(process.env, env);
  const { verifyRouter } = await import("./routes/verifyRoute");
  const app = express(); app.use(express.json()); app.use("/api", verifyRouter);
  const api = app.listen(0, "127.0.0.1");
  await new Promise<void>(resolve => api.once("listening", resolve));
  const post = async (token = "a".repeat(64)) => {
    const response = await fetch(`${address(api)}/api/verify-and-create`, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: JSON.stringify({ provider: "telebirr", reference: "DHU5AM9UB3", expectedAmount: 1400, tableNumber: "Invoice: INV-1042", receiptImageBase64: "cGhvdG8=" }) });
    return { status: response.status, body: await response.json() as Record<string, unknown> };
  };
  try {
    assert.equal((await post("invalid")).status, 401);
    assert.equal(calls, 0);
    assert.equal((await post()).status, 201);
    assert.equal(commits, 1);
    assert.equal(committed.p_table_number, "Invoice: INV-1042");
    assert.equal(committed.p_verified_amount, 1500);
    assert.ok(!JSON.stringify(committed).includes("test-private-key"));
    existing = true;
    const before = calls;
    assert.equal((await post()).status, 200);
    assert.equal(calls, before);
    existing = false;
    for (const [override, code] of [
      [{ creditedPartyAccountNo: "0911999999" }, "DESTINATION_MISMATCH"],
      [{ settledAmount: "1200" }, "UNDERPAID"],
      [{ paymentDate: "2020-01-01T00:00:00Z" }, "TRANSACTION_TOO_OLD"],
      [{ receiptNo: "DIFFERENT" }, "NOT_VERIFIED"],
    ] as const) {
      payload = { success: true, data: receipt(override) };
      assert.equal((await post()).body.code, code);
      assert.equal(commits, 1);
    }
    for (const [httpStatus, code, retryable] of [[401, "VERITAS_ACCESS_DENIED", false], [402, "VERITAS_CREDITS_EXHAUSTED", false], [429, "VERITAS_RATE_LIMIT", true], [503, "VERITAS_UNAVAILABLE", true]] as const) {
      status = httpStatus;
      payload = { error: "upstream diagnostic test-private-key" };
      await assert.rejects(verifyWithVeritas("telebirr", { reference: "DHU5AM9UB3" }), error => {
        assert.ok(error instanceof OwnedVerifierError); assert.equal(error.code, code); assert.equal(error.retryable, retryable); assert.ok(!error.message.includes("test-private-key")); return true;
      });
    }
  } finally {
    for (const [key, value] of Object.entries(previous)) { if (value === undefined) delete process.env[key]; else process.env[key] = value; }
    for (const server of [api, upstream, database]) await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});
