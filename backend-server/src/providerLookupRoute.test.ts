import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";
import express from "express";
import { providerLookupRouter } from "./routes/providerLookupRoute";

test("private provider lookup rejects missing keys and returns owned receipt evidence", async () => {
  const relay = createServer((request, response) => {
    const url = new URL(request.url!, "http://localhost");
    assert.equal(url.searchParams.get("key"), "private-relay-key");
    assert.equal(url.searchParams.get("reference"), "EBEB123456789");
    response.setHeader("Content-Type", "application/json");
    response.end(JSON.stringify({ success: true, data: {
      payerName: "Test Sender", creditedPartyName: "Test Business",
      creditedPartyAccountNo: "0911000099", transactionStatus: "Completed",
      receiptNo: "EBEB123456789", paymentDate: "15-10-2026 12:00:00",
      settledAmount: "150.00 Birr",
    } }));
  });
  await new Promise<void>((done) => relay.listen(0, "127.0.0.1", done));
  const relayAddress = relay.address();
  assert.ok(relayAddress && typeof relayAddress !== "string");
  const values = {
    NODE_ENV: "test", CHEKMI_VERIFICATION_ENGINE: "owned", CHEKMI_PROVIDER_EGRESS: "proxy",
    CHEKMI_INTERNAL_LOOKUP_KEY: "private-internal-key",
    TELEBIRR_PROXY_URLS: `http://127.0.0.1:${relayAddress.port}/verify.php`,
    TELEBIRR_PROXY_KEY: "private-relay-key",
  };
  const previous = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
  Object.assign(process.env, values);
  const app = express();
  app.use(express.json());
  app.use("/api", providerLookupRouter);
  const server = app.listen(0, "127.0.0.1");
  await new Promise<void>((done) => server.once("listening", done));
  const apiAddress = server.address();
  assert.ok(apiAddress && typeof apiAddress !== "string");
  const endpoint = `http://127.0.0.1:${apiAddress.port}/api/internal/provider-lookup`;
  try {
    const body = JSON.stringify({ provider: "telebirr", reference: "EBEB123456789" });
    const denied = await fetch(endpoint, { method: "POST", headers: {"Content-Type":"application/json"}, body });
    assert.equal(denied.status, 401);
    const accepted = await fetch(endpoint, { method: "POST", headers: {"Content-Type":"application/json", "x-chekmi-lookup-key":"private-internal-key"}, body });
    assert.equal(accepted.status, 200);
    const result = await accepted.json() as Record<string, any>;
    assert.equal(result.ok, true);
    assert.equal(result.data.amount, 150);
    assert.equal(result.data.receiverAccount, "0911000099");
    assert.ok(!JSON.stringify(result).includes("private-"));
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    await Promise.all([
      new Promise<void>((done) => server.close(() => done())),
      new Promise<void>((done) => relay.close(() => done())),
    ]);
  }
});

test("isolated staging fixtures never contact a live provider relay", async () => {
  let relayRequests = 0;
  const relay = createServer((_request, response) => {
    relayRequests++;
    response.writeHead(503).end();
  });
  await new Promise<void>((done) => relay.listen(0, "127.0.0.1", done));
  const relayAddress = relay.address();
  assert.ok(relayAddress && typeof relayAddress !== "string");
  const values = {
    NODE_ENV: "production",
    CHEKMI_ENV: "staging",
    CHEKMI_VERIFIER_MODE: "fixtures",
    CHEKMI_VERIFICATION_ENGINE: "owned",
    CHEKMI_PROVIDER_EGRESS: "proxy",
    CHEKMI_INTERNAL_LOOKUP_KEY: "staging-test-only-key",
    TELEBIRR_PROXY_URLS: `http://127.0.0.1:${relayAddress.port}/verify.php`,
    TELEBIRR_PROXY_KEY: "local-only-key",
  };
  const previous = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
  Object.assign(process.env, values);
  const app = express();
  app.use(express.json());
  app.use("/api", providerLookupRouter);
  const server = app.listen(0, "127.0.0.1");
  await new Promise<void>((done) => server.once("listening", done));
  const apiAddress = server.address();
  assert.ok(apiAddress && typeof apiAddress !== "string");
  const endpoint = `http://127.0.0.1:${apiAddress.port}/api/internal/provider-lookup`;
  try {
    const headers = { "Content-Type": "application/json", "x-chekmi-lookup-key": "staging-test-only-key" };
    const missing = await fetch(endpoint, {
      method: "POST", headers,
      body: JSON.stringify({ provider: "telebirr", reference: "CHEKMI-OK" }),
    });
    assert.equal(missing.status, 400);
    const accepted = await fetch(endpoint, {
      method: "POST", headers,
      body: JSON.stringify({ provider: "telebirr", reference: "CHEKMI-OK",
        expectedAmount: 150, receivingAccount: "0911000099" }),
    });
    assert.equal(accepted.status, 200);
    const result = await accepted.json() as Record<string, any>;
    assert.equal(result.ok, true);
    assert.equal(result.data.fixture, true);
    assert.equal(result.data.amount, 150);
    assert.equal(result.data.receiverAccount, "0911000099");
    assert.equal(relayRequests, 0);
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    await Promise.all([
      new Promise<void>((done) => server.close(() => done())),
      new Promise<void>((done) => relay.close(() => done())),
    ]);
  }
});
