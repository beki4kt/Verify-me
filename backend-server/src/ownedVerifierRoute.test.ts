import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";

import express from "express";

test("CHEKMI legacy API route uses the owned Telebirr verifier", async () => {
  const provider = createServer((_request, response) => {
    response.writeHead(200, { "content-type": "text/html" });
    response.end(`
      <table>
        <tr><td>Payer Name</td><td>Abebe Kebede</td></tr>
        <tr><td>Payer telebirr no.</td><td>0911222333</td></tr>
        <tr><td>Credited Party name</td><td>Mesob Restaurant</td></tr>
        <tr><td>Credited party account no</td><td>0911000099</td></tr>
        <tr><td>Transaction status</td><td>Completed</td></tr>
        <tr><td>Receipt No.</td><td>EBEB123456789</td></tr>
        <tr><td>Payment date</td><td>25-08-2026 14:30:00</td></tr>
        <tr><td>Settled Amount</td><td>1,500.00 Birr</td></tr>
        <tr><td>Service fee</td><td>0.00 Birr</td></tr>
        <tr><td>Service fee VAT</td><td>0.00 Birr</td></tr>
        <tr><td>Total Paid Amount</td><td>1,500.00 Birr</td></tr>
      </table>
    `);
  });
  await new Promise<void>((resolve) => provider.listen(0, "127.0.0.1", resolve));
  const providerAddress = provider.address();
  assert.ok(providerAddress && typeof providerAddress === "object");

  const previousEnvironment = {
    nodeEnv: process.env.NODE_ENV,
    chekmiEnv: process.env.CHEKMI_ENV,
    egress: process.env.CHEKMI_PROVIDER_EGRESS,
    legacy: process.env.ALLOW_LEGACY_VERIFY,
    telebirrBase: process.env.TELEBIRR_RECEIPT_BASE_URL,
  };
  process.env.NODE_ENV = "test";
  process.env.CHEKMI_ENV = "development";
  process.env.CHEKMI_PROVIDER_EGRESS = "direct";
  process.env.ALLOW_LEGACY_VERIFY = "true";
  process.env.TELEBIRR_RECEIPT_BASE_URL =
    `http://127.0.0.1:${providerAddress.port}/receipt`;

  const { verifyRouter } = await import("./routes/verifyRoute");
  const app = express();
  app.use(express.json());
  app.use("/api", verifyRouter);
  const api = app.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => api.once("listening", resolve));
  const apiAddress = api.address();
  assert.ok(apiAddress && typeof apiAddress === "object");

  try {
    const response = await fetch(
      `http://127.0.0.1:${apiAddress.port}/api/verify`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          provider: "telebirr",
          reference: "EBEB123456789",
          expectedAmount: 1200,
        }),
      },
    );
    const body = (await response.json()) as Record<string, unknown>;
    assert.equal(response.status, 200);
    assert.equal(body.success, true);
    const data = body.data as Record<string, unknown>;
    assert.equal(data.amount, 1500);
    assert.equal(data.receiverAccount, "0911000099");
    assert.equal(data.tipAmount, 300);
  } finally {
    await Promise.all([
      new Promise<void>((resolve, reject) =>
        api.close((error) => (error ? reject(error) : resolve())),
      ),
      new Promise<void>((resolve, reject) =>
        provider.close((error) => (error ? reject(error) : resolve())),
      ),
    ]);
    restoreEnv("NODE_ENV", previousEnvironment.nodeEnv);
    restoreEnv("CHEKMI_ENV", previousEnvironment.chekmiEnv);
    restoreEnv("CHEKMI_PROVIDER_EGRESS", previousEnvironment.egress);
    restoreEnv("ALLOW_LEGACY_VERIFY", previousEnvironment.legacy);
    restoreEnv(
      "TELEBIRR_RECEIPT_BASE_URL",
      previousEnvironment.telebirrBase,
    );
  }
});

function restoreEnv(name: string, value: string | undefined): void {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
