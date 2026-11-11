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
const veritasVerifier_1 = require("./veritasVerifier");
const ownedVerifier_1 = require("./ownedVerifier");
const receipt = (overrides = {}) => ({
    payerName: "Test Sender", payerTelebirrNo: "0911222333",
    creditedPartyName: "Test Business", creditedPartyAccountNo: "0911000099",
    transactionStatus: "Completed", receiptNo: "DHU5AM9UB3",
    paymentDate: new Date().toISOString(), settledAmount: "1,500.00 Birr",
    totalPaidAmount: "1,505.00 Birr", serviceFee: "5.00 Birr", ...overrides,
});
(0, node_test_1.default)("Veritas readiness requires a private key and safe URL; owned remains explicit fallback", () => {
    strict_1.default.equal((0, veritasVerifier_1.verifierConfiguration)({ CHEKMI_VERIFICATION_ENGINE: "veritas" }).configured, false);
    strict_1.default.equal((0, veritasVerifier_1.verifierConfiguration)({ CHEKMI_VERIFICATION_ENGINE: "veritas", VERITAS_API_KEY: "test" }).configured, true);
    strict_1.default.equal((0, veritasVerifier_1.verifierConfiguration)({ CHEKMI_VERIFICATION_ENGINE: "veritas", VERITAS_API_KEY: "test", VERITAS_API_URL: "http://example.com" }).configured, false);
    strict_1.default.equal((0, veritasVerifier_1.verifierConfiguration)({ CHEKMI_VERIFICATION_ENGINE: "typo" }).configured, false);
    strict_1.default.equal((0, veritasVerifier_1.verifierConfiguration)({}).engine, "owned");
});
(0, node_test_1.default)("ID request whitelist excludes photos and preserves provider-specific fields", () => {
    const input = { reference: " tx12345678 ", suffix: "12345678", phoneNumber: "0911222333", receiptImageBase64: "must-not-leave-server", expectedAmount: 999 };
    strict_1.default.deepEqual((0, veritasVerifier_1.veritasRequest)("telebirr", input).body, { reference: "TX12345678" });
    strict_1.default.deepEqual((0, veritasVerifier_1.veritasRequest)("cbe", input).body, { reference: "TX12345678", accountSuffix: "12345678" });
    strict_1.default.deepEqual((0, veritasVerifier_1.veritasRequest)("abyssinia", { ...input, suffix: "12345" }).body, { reference: "TX12345678", suffix: "12345" });
    strict_1.default.deepEqual((0, veritasVerifier_1.veritasRequest)("cbebirr", input).body, { receiptNumber: "TX12345678", phoneNumber: "251911222333" });
    for (const provider of ["telebirr", "cbe", "abyssinia", "cbebirr", "dashen", "mpesa"]) {
        strict_1.default.equal((0, veritasVerifier_1.veritasRequest)(provider, input).path, `/verify-${provider}`);
        strict_1.default.ok(!JSON.stringify((0, veritasVerifier_1.veritasRequest)(provider, input)).includes("must-not-leave-server"));
    }
});
(0, node_test_1.default)("Telebirr maps the principal instead of total including fees", () => {
    const result = (0, veritasVerifier_1.normalizeVeritas)("telebirr", "DHU5AM9UB3", { success: true, data: receipt() });
    strict_1.default.equal(result.ok, true);
    if (result.ok) {
        strict_1.default.equal(result.data.amount, 1500);
        strict_1.default.equal(result.data.totalAmount, 1505);
        strict_1.default.equal(result.data.receiverAccount, "0911000099");
    }
});
(0, node_test_1.default)("nested provider failures, mismatched IDs, pending statuses and malformed money fail closed", () => {
    for (const payload of [
        { success: false, data: receipt() },
        { success: true, data: { success: false, data: receipt() } },
        { success: true, data: receipt({ receiptNo: "DIFFERENT" }) },
        { success: true, data: receipt({ transactionStatus: "Pending" }) },
        { success: true, data: receipt({ settledAmount: "error 1500" }) },
        { success: true, data: receipt({ settledAmount: null }) },
        { success: true, data: receipt({ paymentDate: null }) },
        { success: true, data: receipt({ currency: "USD" }) },
        { success: true, data: {} },
        "<html>Bad gateway</html>",
    ])
        strict_1.default.equal((0, veritasVerifier_1.normalizeVeritas)("telebirr", "DHU5AM9UB3", payload).ok, false);
});
(0, node_test_1.default)("bank envelopes normalize without borrowing submitted receipt fields", () => {
    const date = new Date().toISOString();
    const samples = [
        ["cbe", "FT1234567890", { success: true, reference: "FT1234567890", amount: 1500, paymentDate: date, receiverAccount: "1000123456789" }],
        ["dashen", "1234567890123456", { success: true, transactionReference: "1234567890123456", transactionAmount: 1500, transactionDate: date, phoneNo: "0911000099" }],
        ["abyssinia", "FT1234567890", { success: true, data: { header: { status: "success" }, body: [{ "Transaction Reference": "FT1234567890", "Transferred Amount": "1500.00", "Transaction Date": date }] } }],
        ["cbebirr", "TX12345678", { customerName: "Test Sender", debitAccount: "0911222333", creditAccount: "0911000099", transactionStatus: "Completed", reference: "Purchase of supplies", receiptNumber: "TX12345678", amount: "1500.00", transactionDate: date }],
        ["mpesa", "TX12345678", { success: true, transactionId: "TX12345678", receiptNo: "OTHER12345", amount: 1500, paymentDate: date, receiverAccount: "0911000099" }],
    ];
    for (const [provider, reference, payload] of samples)
        strict_1.default.equal((0, veritasVerifier_1.normalizeVeritas)(provider, reference, payload).ok, true, provider);
    strict_1.default.equal((0, veritasVerifier_1.normalizeVeritas)("dashen", "1234567890123456", { success: true, transactionReference: "9999999999999999", transactionAmount: 1500, transactionDate: date }).ok, false);
});
(0, node_test_1.default)("authenticated ID verification enforces destination, amount, date, duplicate recovery and secret isolation", async () => {
    let status = 200;
    let payload = { success: true, data: receipt() };
    let calls = 0;
    let commits = 0;
    let existing = false;
    let committed = {};
    const upstream = (0, node_http_1.createServer)(async (req, res) => {
        calls++;
        strict_1.default.equal(req.url, "/verify-telebirr");
        strict_1.default.equal(req.headers["x-api-key"], "test-private-key");
        let body = "";
        for await (const chunk of req)
            body += chunk;
        strict_1.default.deepEqual(JSON.parse(body), { reference: "DHU5AM9UB3" });
        res.writeHead(status, { "Content-Type": "application/json" });
        res.end(JSON.stringify(payload));
    });
    const database = (0, node_http_1.createServer)(async (req, res) => {
        let text = "";
        for await (const chunk of req)
            text += chunk;
        const params = JSON.parse(text);
        res.setHeader("Content-Type", "application/json");
        switch (req.url?.split("/").pop()) {
            case "get_verification_context":
                res.end(JSON.stringify({ business_id: "test-business", staff_number: "01", role: "waiter", provider: "telebirr", receiving_account: "0911000099" }));
                break;
            case "find_committed_payment":
                res.end(JSON.stringify(existing ? { ticket_id: "ticket-one", reference: "DHU5AM9UB3" } : null));
                break;
            case "commit_verified_payment":
                commits++;
                committed = params;
                res.end(JSON.stringify({ ticket_id: "ticket-one" }));
                break;
            case "service_record_failed_verification":
                res.end("null");
                break;
            default:
                res.statusCode = 404;
                res.end("{}");
        }
    });
    for (const server of [upstream, database])
        await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
    const address = (server) => { const a = server.address(); strict_1.default.ok(a && typeof a !== "string"); return `http://127.0.0.1:${a.port}`; };
    const env = { NODE_ENV: "test", CHEKMI_ENV: "development", CHEKMI_VERIFIER_MODE: "live", CHEKMI_VERIFICATION_ENGINE: "veritas", VERITAS_API_KEY: "test-private-key", VERITAS_API_URL: address(upstream), SUPABASE_URL: address(database), SUPABASE_SERVICE_ROLE_KEY: "test-database-key" };
    const previous = Object.fromEntries(Object.keys(env).map(key => [key, process.env[key]]));
    Object.assign(process.env, env);
    const { verifyRouter } = await Promise.resolve().then(() => __importStar(require("./routes/verifyRoute")));
    const app = (0, express_1.default)();
    app.use(express_1.default.json());
    app.use("/api", verifyRouter);
    const api = app.listen(0, "127.0.0.1");
    await new Promise(resolve => api.once("listening", resolve));
    const post = async (token = "a".repeat(64)) => {
        const response = await fetch(`${address(api)}/api/verify-and-create`, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: JSON.stringify({ provider: "telebirr", reference: "DHU5AM9UB3", expectedAmount: 1400, tableNumber: "Invoice: INV-1042", receiptImageBase64: "cGhvdG8=" }) });
        return { status: response.status, body: await response.json() };
    };
    try {
        strict_1.default.equal((await post("invalid")).status, 401);
        strict_1.default.equal(calls, 0);
        strict_1.default.equal((await post()).status, 201);
        strict_1.default.equal(commits, 1);
        strict_1.default.equal(committed.p_table_number, "Invoice: INV-1042");
        strict_1.default.equal(committed.p_verified_amount, 1500);
        strict_1.default.ok(!JSON.stringify(committed).includes("test-private-key"));
        existing = true;
        const before = calls;
        strict_1.default.equal((await post()).status, 200);
        strict_1.default.equal(calls, before);
        existing = false;
        for (const [override, code] of [
            [{ creditedPartyAccountNo: "0911999999" }, "DESTINATION_MISMATCH"],
            [{ settledAmount: "1200" }, "UNDERPAID"],
            [{ paymentDate: "2020-01-01T00:00:00Z" }, "TRANSACTION_TOO_OLD"],
            [{ receiptNo: "DIFFERENT" }, "NOT_VERIFIED"],
        ]) {
            payload = { success: true, data: receipt(override) };
            strict_1.default.equal((await post()).body.code, code);
            strict_1.default.equal(commits, 1);
        }
        for (const [httpStatus, code, retryable] of [[401, "VERITAS_ACCESS_DENIED", false], [402, "VERITAS_CREDITS_EXHAUSTED", false], [429, "VERITAS_RATE_LIMIT", true], [503, "VERITAS_UNAVAILABLE", true]]) {
            status = httpStatus;
            payload = { error: "upstream diagnostic test-private-key" };
            await strict_1.default.rejects((0, veritasVerifier_1.verifyWithVeritas)("telebirr", { reference: "DHU5AM9UB3" }), error => {
                strict_1.default.ok(error instanceof ownedVerifier_1.OwnedVerifierError);
                strict_1.default.equal(error.code, code);
                strict_1.default.equal(error.retryable, retryable);
                strict_1.default.ok(!error.message.includes("test-private-key"));
                return true;
            });
        }
    }
    finally {
        for (const [key, value] of Object.entries(previous)) {
            if (value === undefined)
                delete process.env[key];
            else
                process.env[key] = value;
        }
        for (const server of [api, upstream, database])
            await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    }
});
//# sourceMappingURL=veritasVerifier.test.js.map