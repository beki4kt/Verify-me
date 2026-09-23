"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_crypto_1 = require("node:crypto");
const node_http_1 = require("node:http");
const node_test_1 = __importDefault(require("node:test"));
const ownedVerifier_1 = require("./ownedVerifier");
const { providerTlsOptions, providerHttpsAgent } = require("../scripts/provider-tls.cjs");
(0, node_test_1.default)("M-Pesa supplies its missing public intermediate without weakening TLS or other hosts", () => {
    const options = providerTlsOptions("m-pesabusiness.safaricom.et");
    strict_1.default.equal(options.rejectUnauthorized, true);
    strict_1.default.equal(options.allowPartialTrustChain, false);
    strict_1.default.equal(options.minVersion, "TLSv1.2");
    strict_1.default.ok(Array.isArray(options.ca));
    const intermediate = new node_crypto_1.X509Certificate(options.ca[options.ca.length - 1]);
    strict_1.default.equal(intermediate.ca, true);
    strict_1.default.equal(intermediate.fingerprint256, "C8:02:5F:9F:C6:5F:DF:C9:5B:3C:A8:CC:78:67:B9:A5:87:B5:27:79:73:95:79:17:46:3F:C8:13:D0:B6:25:A9");
    strict_1.default.equal(providerTlsOptions("mb.cbe.com.et").ca, undefined);
    strict_1.default.equal(providerHttpsAgent(new URL("https://relay.example/")), undefined);
    strict_1.default.equal(providerHttpsAgent(new URL("http://m-pesabusiness.safaricom.et/")), undefined);
});
(0, node_test_1.default)("disabled legacy CBE fails closed while new-format CBE still uses its own route", async () => {
    let calls = 0;
    const token = "new-receipt-token-12345";
    const upstream = (0, node_http_1.createServer)((request, response) => {
        calls++;
        strict_1.default.equal(request.url, `/transactions/${token}`);
        strict_1.default.equal(request.headers["x-app-id"], "test-app-id");
        strict_1.default.equal(request.headers["x-app-version"], "test-version");
        response.setHeader("Content-Type", "application/json");
        response.end(JSON.stringify({ success: true, data: {
                debitAccountHolder: "Test Sender", debitAccountNo: "1000000000001",
                creditAccountHolder: "Test Business", creditAccountNo: "1000000000002",
                amountCredited: "150.00", dateTimes: ["2026-09-06 12:00:00"],
                id: "FT1234567890", paymentDetails: ["Test"],
            } }));
    });
    await new Promise((done) => upstream.listen(0, "127.0.0.1", done));
    const address = upstream.address();
    strict_1.default.ok(address && typeof address !== "string");
    const values = {
        NODE_ENV: "test", CHEKMI_PROVIDER_EGRESS: "direct", SKIP_PRIMARY_VERIFICATION: "false",
        CBE_LEGACY_ENABLED: "false", CBE_APP_ID: "test-app-id", CBE_APP_VERSION: "test-version",
        CBE_NEW_RECEIPT_BASE_URL: `http://127.0.0.1:${address.port}/transactions`,
    };
    const previous = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
    Object.assign(process.env, values);
    try {
        await strict_1.default.rejects((0, ownedVerifier_1.verifyCbeOwned)("FT1234567890", "12345678"), (error) => {
            strict_1.default.ok(error instanceof ownedVerifier_1.OwnedVerifierError);
            strict_1.default.equal(error.status, 503);
            strict_1.default.equal(error.retryable, true);
            strict_1.default.equal(error.code, "PROVIDER_UNAVAILABLE");
            return true;
        });
        strict_1.default.equal(calls, 0);
        const result = await (0, ownedVerifier_1.verifyCbeOwned)(`https://mbreciept.cbe.com.et/${token}`);
        strict_1.default.equal(result.ok, true);
        if (result.ok) {
            strict_1.default.equal(result.data.amount, 150);
            strict_1.default.equal(result.data.receiverAccount, "1000000000002");
        }
        strict_1.default.equal(calls, 1);
    }
    finally {
        for (const [key, value] of Object.entries(previous)) {
            if (value === undefined)
                delete process.env[key];
            else
                process.env[key] = value;
        }
        await new Promise((done, reject) => upstream.close((error) => error ? reject(error) : done()));
    }
});
//# sourceMappingURL=hosting.test.js.map