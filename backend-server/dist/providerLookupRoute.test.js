"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_http_1 = require("node:http");
const node_test_1 = __importDefault(require("node:test"));
const express_1 = __importDefault(require("express"));
const providerLookupRoute_1 = require("./routes/providerLookupRoute");
(0, node_test_1.default)("private provider lookup rejects missing keys and returns owned receipt evidence", async () => {
    const relay = (0, node_http_1.createServer)((request, response) => {
        const url = new URL(request.url, "http://localhost");
        strict_1.default.equal(url.searchParams.get("key"), "private-relay-key");
        strict_1.default.equal(url.searchParams.get("reference"), "EBEB123456789");
        response.setHeader("Content-Type", "application/json");
        response.end(JSON.stringify({ success: true, data: {
                payerName: "Test Sender", creditedPartyName: "Test Business",
                creditedPartyAccountNo: "0911000099", transactionStatus: "Completed",
                receiptNo: "EBEB123456789", paymentDate: "15-10-2026 12:00:00",
                settledAmount: "150.00 Birr",
            } }));
    });
    await new Promise((done) => relay.listen(0, "127.0.0.1", done));
    const relayAddress = relay.address();
    strict_1.default.ok(relayAddress && typeof relayAddress !== "string");
    const values = {
        NODE_ENV: "test", CHEKMI_VERIFICATION_ENGINE: "owned", CHEKMI_PROVIDER_EGRESS: "proxy",
        CHEKMI_INTERNAL_LOOKUP_KEY: "private-internal-key",
        TELEBIRR_PROXY_URLS: `http://127.0.0.1:${relayAddress.port}/verify.php`,
        TELEBIRR_PROXY_KEY: "private-relay-key",
    };
    const previous = Object.fromEntries(Object.keys(values).map((key) => [key, process.env[key]]));
    Object.assign(process.env, values);
    const app = (0, express_1.default)();
    app.use(express_1.default.json());
    app.use("/api", providerLookupRoute_1.providerLookupRouter);
    const server = app.listen(0, "127.0.0.1");
    await new Promise((done) => server.once("listening", done));
    const apiAddress = server.address();
    strict_1.default.ok(apiAddress && typeof apiAddress !== "string");
    const endpoint = `http://127.0.0.1:${apiAddress.port}/api/internal/provider-lookup`;
    try {
        const body = JSON.stringify({ provider: "telebirr", reference: "EBEB123456789" });
        const denied = await fetch(endpoint, { method: "POST", headers: { "Content-Type": "application/json" }, body });
        strict_1.default.equal(denied.status, 401);
        const accepted = await fetch(endpoint, { method: "POST", headers: { "Content-Type": "application/json", "x-chekmi-lookup-key": "private-internal-key" }, body });
        strict_1.default.equal(accepted.status, 200);
        const result = await accepted.json();
        strict_1.default.equal(result.ok, true);
        strict_1.default.equal(result.data.amount, 150);
        strict_1.default.equal(result.data.receiverAccount, "0911000099");
        strict_1.default.ok(!JSON.stringify(result).includes("private-"));
    }
    finally {
        for (const [key, value] of Object.entries(previous)) {
            if (value === undefined)
                delete process.env[key];
            else
                process.env[key] = value;
        }
        await Promise.all([
            new Promise((done) => server.close(() => done())),
            new Promise((done) => relay.close(() => done())),
        ]);
    }
});
//# sourceMappingURL=providerLookupRoute.test.js.map