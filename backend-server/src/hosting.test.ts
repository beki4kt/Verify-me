import assert from "node:assert/strict";
import { X509Certificate } from "node:crypto";
import { createServer } from "node:http";
import type { ConnectionOptions } from "node:tls";
import test from "node:test";
import { OwnedVerifierError, verifyCbeOwned } from "./ownedVerifier";

const { providerTlsOptions, providerHttpsAgent } = require("../scripts/provider-tls.cjs") as {
  providerTlsOptions(host: string): ConnectionOptions;
  providerHttpsAgent(url: URL): unknown;
};

test("M-Pesa supplies its missing public intermediate without weakening TLS or other hosts", () => {
  const options = providerTlsOptions("m-pesabusiness.safaricom.et");
  assert.equal(options.rejectUnauthorized, true);
  assert.equal(options.allowPartialTrustChain, false);
  assert.equal(options.minVersion, "TLSv1.2");
  assert.ok(Array.isArray(options.ca));
  const intermediate = new X509Certificate(options.ca[options.ca.length - 1] as string);
  assert.equal(intermediate.ca, true);
  assert.equal(intermediate.fingerprint256, "C8:02:5F:9F:C6:5F:DF:C9:5B:3C:A8:CC:78:67:B9:A5:87:B5:27:79:73:95:79:17:46:3F:C8:13:D0:B6:25:A9");
  assert.equal(providerTlsOptions("mb.cbe.com.et").ca, undefined);
  assert.equal(providerHttpsAgent(new URL("https://relay.example/")), undefined);
  assert.equal(providerHttpsAgent(new URL("http://m-pesabusiness.safaricom.et/")), undefined);
});

test("disabled legacy CBE fails closed while new-format CBE still uses its own route", async () => {
  let calls = 0;
  const token = "new-receipt-token-12345";
  const upstream = createServer((request, response) => {
    calls++;
    assert.equal(request.url, `/transactions/${token}`);
    assert.equal(request.headers["x-app-id"], "test-app-id");
    assert.equal(request.headers["x-app-version"], "test-version");
    response.setHeader("Content-Type", "application/json");
    response.end(JSON.stringify({ success: true, data: {
      debitAccountHolder: "Test Sender", debitAccountNo: "1000000000001",
      creditAccountHolder: "Test Business", creditAccountNo: "1000000000002",
      amountCredited: "150.00", dateTimes: ["2026-09-06 12:00:00"],
      id: "FT1234567890", paymentDetails: ["Test"],
    } }));
  });
  await new Promise<void>((done) => upstream.listen(0, "127.0.0.1", done));
  const address = upstream.address();
  assert.ok(address && typeof address !== "string");
  const values = {
    NODE_ENV: "test", CHEKMI_PROVIDER_EGRESS: "direct", SKIP_PRIMARY_VERIFICATION: "false",
    CBE_LEGACY_ENABLED: "false", CBE_APP_ID: "test-app-id", CBE_APP_VERSION: "test-version",
    CBE_NEW_RECEIPT_BASE_URL: `http://127.0.0.1:${address.port}/transactions`,
  };
  const previous = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
  Object.assign(process.env, values);
  try {
    await assert.rejects(verifyCbeOwned("FT1234567890", "12345678"), (error: unknown) => {
      assert.ok(error instanceof OwnedVerifierError);
      assert.equal(error.status, 503);
      assert.equal(error.retryable, true);
      assert.equal(error.code, "PROVIDER_UNAVAILABLE");
      return true;
    });
    assert.equal(calls, 0);
    const result = await verifyCbeOwned(`https://mbreciept.cbe.com.et/${token}`);
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.equal(result.data.amount, 150);
      assert.equal(result.data.receiverAccount, "1000000000002");
    }
    assert.equal(calls, 1);
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    await new Promise<void>((done, reject) => upstream.close((error) => error ? reject(error) : done()));
  }
});
