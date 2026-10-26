import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";

import { OwnedVerifierError, verifyMpesaOwned } from "./ownedVerifier";

test("M-Pesa relay accepts a matching JSON receipt and fails closed on bad evidence", async () => {
  let reply: Record<string, unknown> = {};
  const relay = createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://localhost");
    assert.equal(url.pathname, "/mpesa.php");
    assert.equal(url.searchParams.get("reference"), "SCW4GOZXQZDJ");
    assert.equal(url.searchParams.get("key"), "local-test-key");
    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify(reply));
  });
  await new Promise<void>(resolve => relay.listen(0, "127.0.0.1", resolve));
  const address = relay.address();
  assert.ok(address && typeof address === "object");
  const values = {
    NODE_ENV: "test", CHEKMI_PROVIDER_EGRESS: "proxy",
    MPESA_PROXY_URL: `http://127.0.0.1:${address.port}/mpesa.php`,
    MPESA_PROXY_KEY: "local-test-key",
  };
  const previous = Object.fromEntries(Object.keys(values).map(key => [key, process.env[key]]));
  Object.assign(process.env, values);
  const receipt = (changes: Record<string, unknown> = {}) => ({
    receiptNo: "SCW4GOZXQZDJ", transactionId: "TRX12345678",
    transactionAmount: "250.00", transactionDate: "2026-10-26 12:00:00",
    receiverAccount: "0711000099", transactionStatus: "Completed", currency: "ETB",
    ...changes,
  });
  const encoded = (value: unknown) => ({
    responseCode: "0", base64Data: Buffer.from(JSON.stringify(value)).toString("base64"),
  });
  try {
    const invalid = await verifyMpesaOwned("SCW-4GOZXQZDJ");
    assert.equal(invalid.ok, false);
    if (!invalid.ok) assert.equal(invalid.code, "INVALID_REFERENCE");
    reply = encoded(receipt());
    const success = await verifyMpesaOwned("SCW4GOZXQZDJ");
    assert.equal(success.ok, true);
    if (success.ok) {
      assert.equal(success.data.amount, 250);
      assert.equal(success.data.receiverAccount, "0711000099");
      assert.equal(success.data.txnDate, "2026-10-26T09:00:00.000Z");
    }
    for (const changes of [
      { receiptNo: "ANOTHER12345" }, { receiverAccount: null },
      { transactionStatus: "Pending" }, { transactionAmount: "250.001" },
      { currency: "USD" },
    ]) {
      reply = encoded(receipt(changes));
      assert.equal((await verifyMpesaOwned("SCW4GOZXQZDJ")).ok, false);
    }
    reply = { responseCode: "2032", responseDescription: "The receipt does not exist." };
    const missing = await verifyMpesaOwned("SCW4GOZXQZDJ");
    assert.equal(missing.ok, false);
    if (!missing.ok) assert.equal(missing.code, "RECEIPT_NOT_FOUND");
    reply = { success: false, responseCode: "401", responseDescription: "Unauthorized" };
    await assert.rejects(verifyMpesaOwned("SCW4GOZXQZDJ"), (error: unknown) => {
      assert.ok(error instanceof OwnedVerifierError);
      assert.equal(error.code, "VERIFIER_CONFIGURATION_ERROR");
      return true;
    });
    reply = { responseCode: "0", base64Data: Buffer.from("not a receipt").toString("base64") };
    assert.equal((await verifyMpesaOwned("SCW4GOZXQZDJ")).ok, false);
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    await new Promise<void>(resolve => relay.close(() => resolve()));
  }
});
