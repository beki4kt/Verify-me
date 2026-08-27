import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";

import {
  completedStatus,
  ethiopianLocalDate,
  ownedVerifierConfiguration,
  parseCbeBirrText,
  parseCbeText,
  parseDashenText,
  parseTelebirrHtml,
  parseWalletText,
  verifyWithOwnedRoute,
} from "./ownedVerifier";

const telebirrHtml = `
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
`;

test("owned verifier reports direct and relay capabilities without secrets", () => {
  const configuration = ownedVerifierConfiguration({
    CHEKMI_PROVIDER_EGRESS: "auto",
    TELEBIRR_PROXY_URLS: "https://relay.example/verify.php",
    TELEBIRR_PROXY_KEY: "super-secret-proxy-key",
    CBE_APP_ID: "private-app-id",
    CBE_APP_VERSION: "private-app-version",
  });
  assert.equal(configuration.configured, true);
  assert.equal(configuration.mode, "auto");
  assert.equal(configuration.relays.telebirr, true);
  assert.equal(configuration.relays.cbe, false);
  assert.equal(configuration.newCbeDirectConfigured, true);
  assert.equal(JSON.stringify(configuration).includes("super-secret"), false);
});

test("Ethiopian provider timestamps are converted to UTC", () => {
  assert.equal(
    ethiopianLocalDate("25-08-2026 14:30:00"),
    "2026-08-25T11:30:00.000Z",
  );
  assert.equal(
    ethiopianLocalDate("2026/08/25, 03:00:00 PM"),
    "2026-08-25T12:00:00.000Z",
  );
  assert.equal(
    ethiopianLocalDate("2026/8/5, 3:00:00 PM"),
    "2026-08-05T12:00:00.000Z",
  );
  assert.equal(
    ethiopianLocalDate("2026-08-25T14:30:00"),
    "2026-08-25T11:30:00.000Z",
  );
});

test("only explicit successful provider statuses are accepted", () => {
  assert.equal(completedStatus("Completed"), true);
  assert.equal(completedStatus("Payment successful"), true);
  assert.equal(completedStatus("Unsuccessful"), false);
  assert.equal(completedStatus("Not completed"), false);
  assert.equal(completedStatus("Pending"), false);
});

test("Telebirr HTML parser extracts the destination, amount, and status", () => {
  const receipt = parseTelebirrHtml(telebirrHtml);
  assert.equal(receipt.receiptNo, "EBEB123456789");
  assert.equal(receipt.creditedPartyAccountNo, "0911000099");
  assert.equal(receipt.settledAmount, "1,500.00 Birr");
  assert.equal(receipt.transactionStatus, "Completed");
});

test("CBE legacy text parser preserves masked accounts and receipt time", () => {
  const receipt = parseCbeText(`
    Payer: John Smith Account: A****1234
    Receiver: Mesob Restaurant Account: 1****9012
    Reason / Type of service: Dinner Transferred Amount: 1,500.00 ETB
    Reference No. (VAT Invoice No): FT1234567890
    Payment Date & Time: 2026/08/25, 03:00:00 PM
  `);
  assert.equal(receipt.reference, "FT1234567890");
  assert.equal(receipt.amount, 1500);
  assert.equal(receipt.receiverAccount, "1****9012");
  assert.equal(receipt.date, "2026-08-25T12:00:00.000Z");
});

test("Dashen and wallet receipt parsers expose security-critical fields", () => {
  const dashen = parseDashenText(`
    Sender Name: John Doe Sender Account Number: 10000001
    Receiver Name: Mesob Restaurant Receiver Account Number: 20000002
    Transaction Reference: 1234567890123456
    Transaction Date & Time: 2026-08-25 14:30:00
    Transaction Amount ETB: 800.00 Total ETB: 805.00
  `);
  assert.equal(dashen.reference, "1234567890123456");
  assert.equal(dashen.receiverAccount, "20000002");
  assert.equal(dashen.amount, 800);

  const wallet = parseWalletText(`
    PAYER NAME John Doe PAYER PHONE NUMBER 0911222333
    RECEIVER NAME Mesob Restaurant RECEIVER NUMBER 0711000099
    TRANSACTION ID TRX123ABC RECEIPT NO ABCDE12345F 2026-08-25 14:30:00
    TOTAL 250.00 TRANSACTION STATUS Completed
  `);
  assert.equal(wallet.transactionId, "TRX123ABC");
  assert.equal(wallet.receiverAccount, "0711000099");
  assert.equal(wallet.amount, 250);
  assert.equal(wallet.status, "Completed");
});

test("CBE Birr parser uses its provider-specific PDF layout", () => {
  const receipt = parseCbeBirrText(`
    Sub city: ABEBE KEBEDE Wereda/kebele: 01
    Debit Account 0911222333 Credit Account 0711000099
    Receiver Name Mesob Restaurant Order ID ORD123
    Transaction Status Completed Reference Dinner
    Transaction Details Receipt Number
    ABCDE12345 2026-08-25 14:30 800.00
    800.00 2.00 0.30 802.30 Paid amount
  `);
  assert.equal(receipt.receiptNo, "ABCDE12345");
  assert.equal(receipt.receiverAccount, "0711000099");
  assert.equal(receipt.amount, 800);
  assert.equal(receipt.status, "Completed");
  assert.equal(receipt.date, "2026-08-25T11:30:00.000Z");
});

test("owned Telebirr route fetches and normalizes a local provider response", async () => {
  const server = createServer((_request, response) => {
    response.writeHead(200, { "content-type": "text/html" });
    response.end(telebirrHtml);
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert.ok(address && typeof address === "object");

  const previous = {
    nodeEnv: process.env.NODE_ENV,
    mode: process.env.CHEKMI_PROVIDER_EGRESS,
    base: process.env.TELEBIRR_RECEIPT_BASE_URL,
  };
  process.env.NODE_ENV = "test";
  process.env.CHEKMI_PROVIDER_EGRESS = "direct";
  process.env.TELEBIRR_RECEIPT_BASE_URL =
    `http://127.0.0.1:${address.port}/receipt`;
  try {
    const result = await verifyWithOwnedRoute("telebirr", {
      reference: "EBEB123456789",
    });
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.amount, 1500);
    assert.equal(result.data.receiverAccount, "0911000099");
    assert.equal(result.data.txnDate, "2026-08-25T11:30:00.000Z");
  } finally {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
    restoreEnv("NODE_ENV", previous.nodeEnv);
    restoreEnv("CHEKMI_PROVIDER_EGRESS", previous.mode);
    restoreEnv("TELEBIRR_RECEIPT_BASE_URL", previous.base);
  }
});

function restoreEnv(name: string, value: string | undefined): void {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
