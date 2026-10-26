import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";
import { parseTelebirrHtml, verifyTelebirrOwned } from "./ownedVerifier/telebirr";

// Synthetic data in the nested, bilingual layout observed on the official site.
// No real receipt, payer name or account is retained in this regression fixture.
const reference = "TEST88AB9Z";
const invoice = `<table><tr><td><table>
  <tr><td>የከፋይ ስም/Payer Name</td><td>Test Payer</td></tr>
  <tr><td>የከፋይ ቴሌብር ቁ./Payer telebirr no.</td><td>2519****0001</td></tr>
  <tr><td>የገንዘብ ተቀባይ ስም/Credited Party name</td><td>Test Business</td></tr>
  <tr><td>የገንዘብ ተቀባይ ቴሌብር ቁ./Credited party account no</td><td>2519****0002</td></tr>
  <tr><tr><td>የክፍያው ሁኔታ/transaction status<td>Completed</td></tr>
  </table></td></tr><tr><td><table>
  <tr><td colspan="3">የክፍያ ዝርዝር/ Invoice details</td></tr>
  <tr><td>የክፍያ ቁጥር/Invoice No.</td><td>የክፍያ ቀን/Payment date</td><td>የተከፈለው መጠን/Settled Amount</td></tr>
  <tr><td>${reference}</td><td>06-09-2026 15:20:34</td><td>500 Birr</td></tr>
  <tr><td></td><td>Service fee VAT</td><td>0.26 Birr</td></tr>
  <tr><td colspan="2">Service fee</td><td>1.74 Birr</td></tr>
  <tr><td></td><td>Total Paid Amount</td><td>502 Birr</td></tr>
  </table></td></tr></table>`;

test("Telebirr reads invoice columns and ignores nested ancestor cells and overlapping fee labels", () => {
  const receipt = parseTelebirrHtml(invoice);
  assert.equal(receipt.receiptNo, reference);
  assert.equal(receipt.paymentDate, "06-09-2026 15:20:34");
  assert.equal(receipt.settledAmount, "500 Birr");
  assert.equal(receipt.serviceFee, "1.74 Birr");
  assert.equal(receipt.serviceFeeVAT, "0.26 Birr");
  assert.equal(receipt.totalPaidAmount, "502 Birr");
  assert.equal(receipt.payerName, "Test Payer");
  assert.equal(receipt.creditedPartyAccountNo, "2519****0002");
  assert.equal(receipt.transactionStatus, "Completed");
});

test("Telebirr never uses unrelated text or a neighbouring header as invoice evidence", () => {
  const html = `<p>Receipt No. TEST88AB9Z 06-09-2026 15:20:34 Settled Amount 500 Birr</p>
    <table><tr><td>Invoice No.</td><td>Payment date</td><td>Settled Amount</td></tr></table>`;
  const receipt = parseTelebirrHtml(html);
  assert.equal(receipt.receiptNo, null);
  assert.equal(receipt.paymentDate, null);
  assert.equal(receipt.settledAmount, null);
});

test("Telebirr column receipts verify only with matching provider reference and complete successful evidence", async () => {
  let html = invoice;
  const upstream = createServer((_req, res) => {
    res.setHeader("Content-Type", "text/html");
    res.end(html);
  });
  await new Promise<void>((done) => upstream.listen(0, "127.0.0.1", done));
  const address = upstream.address();
  assert.ok(address && typeof address !== "string");
  const values = { NODE_ENV: "test", CHEKMI_PROVIDER_EGRESS: "direct",
    SKIP_PRIMARY_VERIFICATION: "false", TELEBIRR_RECEIPT_BASE_URL: `http://127.0.0.1:${address.port}/receipt` };
  const previous = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
  Object.assign(process.env, values);
  try {
    const valid = await verifyTelebirrOwned(reference);
    assert.equal(valid.ok, true);
    if (valid.ok) {
      assert.equal(valid.data.reference, reference);
      assert.equal(valid.data.amount, 500);
      assert.equal(valid.data.totalAmount, 502);
      assert.equal(valid.data.txnDate, "2026-09-06T12:20:34.000Z");
    }
    for (const [label, changed] of [
      ["wrong reference", invoice.replace(reference, "OTHER88AB9Z")],
      ["missing reference", invoice.replace(reference, "")],
      ["pending transfer", invoice.replace("Completed", "Pending")],
      ["missing destination", invoice.replace("2519****0002", "")],
      ["missing date", invoice.replace("06-09-2026 15:20:34", "")],
      ["invalid amount", invoice.replace("500 Birr", "0 Birr")],
    ]) {
      html = changed!;
      const result = await verifyTelebirrOwned(reference);
      assert.equal(result.ok, false, label);
      if (!result.ok) assert.equal(result.code, "RECEIPT_MISMATCH", label);
    }
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    await new Promise<void>((done, reject) => upstream.close((error) => error ? reject(error) : done()));
  }
});
