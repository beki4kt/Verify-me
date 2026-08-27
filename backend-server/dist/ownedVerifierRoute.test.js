"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_http_1 = require("node:http");
const node_test_1 = __importDefault(require("node:test"));
const express_1 = __importDefault(require("express"));
(0, node_test_1.default)("CHEKMI legacy API route uses the owned Telebirr verifier", async () => {
    const provider = (0, node_http_1.createServer)((_request, response) => {
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
    await new Promise((resolve) => provider.listen(0, "127.0.0.1", resolve));
    const providerAddress = provider.address();
    strict_1.default.ok(providerAddress && typeof providerAddress === "object");
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
    const { verifyRouter } = await Promise.resolve().then(() => __importStar(require("./routes/verifyRoute")));
    const app = (0, express_1.default)();
    app.use(express_1.default.json());
    app.use("/api", verifyRouter);
    const api = app.listen(0, "127.0.0.1");
    await new Promise((resolve) => api.once("listening", resolve));
    const apiAddress = api.address();
    strict_1.default.ok(apiAddress && typeof apiAddress === "object");
    try {
        const response = await fetch(`http://127.0.0.1:${apiAddress.port}/api/verify`, {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({
                provider: "telebirr",
                reference: "EBEB123456789",
                expectedAmount: 1200,
            }),
        });
        const body = (await response.json());
        strict_1.default.equal(response.status, 200);
        strict_1.default.equal(body.success, true);
        const data = body.data;
        strict_1.default.equal(data.amount, 1500);
        strict_1.default.equal(data.receiverAccount, "0911000099");
        strict_1.default.equal(data.tipAmount, 300);
    }
    finally {
        await Promise.all([
            new Promise((resolve, reject) => api.close((error) => (error ? reject(error) : resolve()))),
            new Promise((resolve, reject) => provider.close((error) => (error ? reject(error) : resolve()))),
        ]);
        restoreEnv("NODE_ENV", previousEnvironment.nodeEnv);
        restoreEnv("CHEKMI_ENV", previousEnvironment.chekmiEnv);
        restoreEnv("CHEKMI_PROVIDER_EGRESS", previousEnvironment.egress);
        restoreEnv("ALLOW_LEGACY_VERIFY", previousEnvironment.legacy);
        restoreEnv("TELEBIRR_RECEIPT_BASE_URL", previousEnvironment.telebirrBase);
    }
});
function restoreEnv(name, value) {
    if (value === undefined)
        delete process.env[name];
    else
        process.env[name] = value;
}
//# sourceMappingURL=ownedVerifierRoute.test.js.map