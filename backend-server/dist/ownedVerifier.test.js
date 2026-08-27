"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_http_1 = require("node:http");
const node_test_1 = __importDefault(require("node:test"));
const ownedVerifier_1 = require("./ownedVerifier");
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
(0, node_test_1.default)("owned verifier reports direct and relay capabilities without secrets", () => {
    const configuration = (0, ownedVerifier_1.ownedVerifierConfiguration)({
        CHEKMI_PROVIDER_EGRESS: "auto",
        TELEBIRR_PROXY_URLS: "https://relay.example/verify.php",
        TELEBIRR_PROXY_KEY: "super-secret-proxy-key",
        CBE_APP_ID: "private-app-id",
        CBE_APP_VERSION: "private-app-version",
    });
    strict_1.default.equal(configuration.configured, true);
    strict_1.default.equal(configuration.mode, "auto");
    strict_1.default.equal(configuration.relays.telebirr, true);
    strict_1.default.equal(configuration.relays.cbe, false);
    strict_1.default.equal(configuration.newCbeDirectConfigured, true);
    strict_1.default.equal(JSON.stringify(configuration).includes("super-secret"), false);
});
(0, node_test_1.default)("Ethiopian provider timestamps are converted to UTC", () => {
    strict_1.default.equal((0, ownedVerifier_1.ethiopianLocalDate)("25-08-2026 14:30:00"), "2026-08-25T11:30:00.000Z");
    strict_1.default.equal((0, ownedVerifier_1.ethiopianLocalDate)("2026/08/25, 03:00:00 PM"), "2026-08-25T12:00:00.000Z");
    strict_1.default.equal((0, ownedVerifier_1.ethiopianLocalDate)("2026/8/5, 3:00:00 PM"), "2026-08-05T12:00:00.000Z");
    strict_1.default.equal((0, ownedVerifier_1.ethiopianLocalDate)("2026-08-25T14:30:00"), "2026-08-25T11:30:00.000Z");
});
(0, node_test_1.default)("only explicit successful provider statuses are accepted", () => {
    strict_1.default.equal((0, ownedVerifier_1.completedStatus)("Completed"), true);
    strict_1.default.equal((0, ownedVerifier_1.completedStatus)("Payment successful"), true);
    strict_1.default.equal((0, ownedVerifier_1.completedStatus)("Unsuccessful"), false);
    strict_1.default.equal((0, ownedVerifier_1.completedStatus)("Not completed"), false);
    strict_1.default.equal((0, ownedVerifier_1.completedStatus)("Pending"), false);
});
(0, node_test_1.default)("Telebirr HTML parser extracts the destination, amount, and status", () => {
    const receipt = (0, ownedVerifier_1.parseTelebirrHtml)(telebirrHtml);
    strict_1.default.equal(receipt.receiptNo, "EBEB123456789");
    strict_1.default.equal(receipt.creditedPartyAccountNo, "0911000099");
    strict_1.default.equal(receipt.settledAmount, "1,500.00 Birr");
    strict_1.default.equal(receipt.transactionStatus, "Completed");
});
(0, node_test_1.default)("CBE legacy text parser preserves masked accounts and receipt time", () => {
    const receipt = (0, ownedVerifier_1.parseCbeText)(`
    Payer: John Smith Account: A****1234
    Receiver: Mesob Restaurant Account: 1****9012
    Reason / Type of service: Dinner Transferred Amount: 1,500.00 ETB
    Reference No. (VAT Invoice No): FT1234567890
    Payment Date & Time: 2026/08/25, 03:00:00 PM
  `);
    strict_1.default.equal(receipt.reference, "FT1234567890");
    strict_1.default.equal(receipt.amount, 1500);
    strict_1.default.equal(receipt.receiverAccount, "1****9012");
    strict_1.default.equal(receipt.date, "2026-08-25T12:00:00.000Z");
});
(0, node_test_1.default)("Dashen and wallet receipt parsers expose security-critical fields", () => {
    const dashen = (0, ownedVerifier_1.parseDashenText)(`
    Sender Name: John Doe Sender Account Number: 10000001
    Receiver Name: Mesob Restaurant Receiver Account Number: 20000002
    Transaction Reference: 1234567890123456
    Transaction Date & Time: 2026-08-25 14:30:00
    Transaction Amount ETB: 800.00 Total ETB: 805.00
  `);
    strict_1.default.equal(dashen.reference, "1234567890123456");
    strict_1.default.equal(dashen.receiverAccount, "20000002");
    strict_1.default.equal(dashen.amount, 800);
    const wallet = (0, ownedVerifier_1.parseWalletText)(`
    PAYER NAME John Doe PAYER PHONE NUMBER 0911222333
    RECEIVER NAME Mesob Restaurant RECEIVER NUMBER 0711000099
    TRANSACTION ID TRX123ABC RECEIPT NO ABCDE12345F 2026-08-25 14:30:00
    TOTAL 250.00 TRANSACTION STATUS Completed
  `);
    strict_1.default.equal(wallet.transactionId, "TRX123ABC");
    strict_1.default.equal(wallet.receiverAccount, "0711000099");
    strict_1.default.equal(wallet.amount, 250);
    strict_1.default.equal(wallet.status, "Completed");
});
(0, node_test_1.default)("CBE Birr parser uses its provider-specific PDF layout", () => {
    const receipt = (0, ownedVerifier_1.parseCbeBirrText)(`
    Sub city: ABEBE KEBEDE Wereda/kebele: 01
    Debit Account 0911222333 Credit Account 0711000099
    Receiver Name Mesob Restaurant Order ID ORD123
    Transaction Status Completed Reference Dinner
    Transaction Details Receipt Number
    ABCDE12345 2026-08-25 14:30 800.00
    800.00 2.00 0.30 802.30 Paid amount
  `);
    strict_1.default.equal(receipt.receiptNo, "ABCDE12345");
    strict_1.default.equal(receipt.receiverAccount, "0711000099");
    strict_1.default.equal(receipt.amount, 800);
    strict_1.default.equal(receipt.status, "Completed");
    strict_1.default.equal(receipt.date, "2026-08-25T11:30:00.000Z");
});
(0, node_test_1.default)("owned Telebirr route fetches and normalizes a local provider response", async () => {
    const server = (0, node_http_1.createServer)((_request, response) => {
        response.writeHead(200, { "content-type": "text/html" });
        response.end(telebirrHtml);
    });
    await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
    const address = server.address();
    strict_1.default.ok(address && typeof address === "object");
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
        const result = await (0, ownedVerifier_1.verifyWithOwnedRoute)("telebirr", {
            reference: "EBEB123456789",
        });
        strict_1.default.equal(result.ok, true);
        if (!result.ok)
            return;
        strict_1.default.equal(result.data.amount, 1500);
        strict_1.default.equal(result.data.receiverAccount, "0911000099");
        strict_1.default.equal(result.data.txnDate, "2026-08-25T11:30:00.000Z");
    }
    finally {
        await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
        restoreEnv("NODE_ENV", previous.nodeEnv);
        restoreEnv("CHEKMI_PROVIDER_EGRESS", previous.mode);
        restoreEnv("TELEBIRR_RECEIPT_BASE_URL", previous.base);
    }
});
function restoreEnv(name, value) {
    if (value === undefined)
        delete process.env[name];
    else
        process.env[name] = value;
}
//# sourceMappingURL=ownedVerifier.test.js.map