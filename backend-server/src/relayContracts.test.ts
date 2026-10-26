import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";

import { OwnedVerifierError, verifyCbeOwned, verifyTelebirrOwned } from "./ownedVerifier";

function restore(previous: Record<string, string | undefined>): void {
  for (const [key, value] of Object.entries(previous)) {
    if (value === undefined) delete process.env[key]; else process.env[key] = value;
  }
}

test("Telebirr relay accepts completed Amharic receipts and distinguishes auth, missing and outage", async () => {
  let reply: Record<string, unknown> = {};
  const server = createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://localhost");
    assert.equal(url.searchParams.get("key"), "local-test-key");
    assert.equal(url.searchParams.get("reference"), "EBEB123456789");
    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify(reply));
  });
  await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
  const address = server.address(); assert.ok(address && typeof address === "object");
  const values = { NODE_ENV: "test", CHEKMI_PROVIDER_EGRESS: "proxy",
    TELEBIRR_PROXY_URLS: `http://127.0.0.1:${address.port}/verify.php`,
    TELEBIRR_PROXY_KEY: "local-test-key" };
  const previous = Object.fromEntries(Object.keys(values).map(key => [key, process.env[key]]));
  Object.assign(process.env, values);
  try {
    reply = { success: true, data: {
      payerName: "Test Customer", creditedPartyName: "Test Business",
      creditedPartyAccountNo: "0911000099", receiptNo: "EBEB123456789",
      settledAmount: "250.00 Birr", paymentDate: "26-10-2026 12:00:00",
      transactionStatus: "ተጠናቅቋል",
    } };
    const success = await verifyTelebirrOwned("EBEB123456789");
    assert.equal(success.ok, true);
    if (success.ok) assert.equal(success.data.amount, 250);
    reply = { success: false, error: "Unauthorized: Invalid or missing proxy key" };
    await assert.rejects(verifyTelebirrOwned("EBEB123456789"), (error: unknown) => {
      assert.ok(error instanceof OwnedVerifierError);
      assert.equal(error.code, "VERIFIER_CONFIGURATION_ERROR");
      assert.equal(error.retryable, false);
      return true;
    });
    reply = { success: false, error: "Receipt not found or the reference is invalid." };
    const missing = await verifyTelebirrOwned("EBEB123456789");
    assert.equal(missing.ok, false);
    if (!missing.ok) assert.equal(missing.code, "RECEIPT_NOT_FOUND");
    reply = { success: false, error: "Telebirr receipt page returned an unexpected format." };
    await assert.rejects(verifyTelebirrOwned("EBEB123456789"), (error: unknown) => {
      assert.ok(error instanceof OwnedVerifierError);
      assert.equal(error.code, "PROVIDER_UNAVAILABLE");
      return true;
    });
  } finally {
    restore(previous);
    await new Promise<void>(resolve => server.close(() => resolve()));
  }
});

test("CBE relay classifies an invalid token separately from an outage or bad key", async () => {
  let status = 500;
  let reply: Record<string, unknown> = { detail: "Security Alert: Invalid or tampered legacy token!" };
  const server = createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://localhost");
    assert.equal(url.searchParams.get("type"), "new");
    assert.equal(url.searchParams.get("token"), "FakeToken1234567890abcdef");
    assert.equal(url.searchParams.get("key"), "local-test-key");
    response.writeHead(status, { "Content-Type": "application/json" });
    response.end(JSON.stringify(reply));
  });
  await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
  const address = server.address(); assert.ok(address && typeof address === "object");
  const values = { NODE_ENV: "test", CHEKMI_PROVIDER_EGRESS: "proxy",
    CBE_PROXY_URL: `http://127.0.0.1:${address.port}/verifyCbe.php`,
    CBE_PROXY_KEY: "local-test-key" };
  const previous = Object.fromEntries(Object.keys(values).map(key => [key, process.env[key]]));
  Object.assign(process.env, values);
  try {
    const lookup = () => verifyCbeOwned("FakeToken1234567890abcdef");
    await assert.rejects(lookup(), (error: unknown) => {
      assert.ok(error instanceof OwnedVerifierError);
      assert.equal(error.code, "INVALID_REFERENCE");
      assert.equal(error.retryable, false);
      return true;
    });
    status = 502; reply = { success: false, error: "Upstream unavailable" };
    await assert.rejects(lookup(), (error: unknown) => {
      assert.ok(error instanceof OwnedVerifierError);
      assert.equal(error.code, "PROVIDER_UNAVAILABLE");
      return true;
    });
    status = 401; reply = { success: false, error: "Unauthorized" };
    await assert.rejects(lookup(), (error: unknown) => {
      assert.ok(error instanceof OwnedVerifierError);
      assert.equal(error.code, "VERIFIER_CONFIGURATION_ERROR");
      return true;
    });
  } finally {
    restore(previous);
    await new Promise<void>(resolve => server.close(() => resolve()));
  }
});
