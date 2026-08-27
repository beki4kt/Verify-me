"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const operatorAuth_1 = require("./operatorAuth");
(0, node_test_1.default)("operator passwords use salted scrypt hashes", () => {
    const encoded = (0, operatorAuth_1.hashOperatorPassword)("A-long-owner-password!2026", Buffer.alloc(16, 7));
    strict_1.default.equal((0, operatorAuth_1.verifyOperatorPassword)("A-long-owner-password!2026", encoded), true);
    strict_1.default.equal((0, operatorAuth_1.verifyOperatorPassword)("incorrect-password", encoded), false);
});
(0, node_test_1.default)("operator login validates password, MFA, and signed expiry", () => {
    const now = Date.parse("2026-08-22T08:00:00.000Z");
    const secret = "JBSWY3DPEHPK3PXP";
    const env = {
        NODE_ENV: "production",
        OPERATOR_EMAIL: "owner@chekmi.test",
        OPERATOR_PASSWORD_HASH: (0, operatorAuth_1.hashOperatorPassword)("A-long-owner-password!2026", Buffer.alloc(16, 9)),
        OPERATOR_TOTP_SECRET: secret,
        OPERATOR_SESSION_SECRET: "a-production-session-secret-that-is-long-enough",
    };
    const login = (0, operatorAuth_1.authenticateOperator)({
        email: "OWNER@CHEKMI.TEST",
        password: "A-long-owner-password!2026",
        code: (0, operatorAuth_1.totpCode)(secret, now),
    }, env, now);
    strict_1.default.equal((0, operatorAuth_1.verifyOperatorToken)(login.token, env, now + 60000).sub, "owner@chekmi.test");
    strict_1.default.throws(() => (0, operatorAuth_1.verifyOperatorToken)(login.token, env, now + 3 * 60 * 60 * 1000));
});
(0, node_test_1.default)("production refuses plaintext or incomplete operator configuration", () => {
    strict_1.default.equal((0, operatorAuth_1.operatorIsConfigured)({
        NODE_ENV: "production",
        OPERATOR_EMAIL: "owner@chekmi.test",
        OPERATOR_PASSWORD: "plaintext",
        OPERATOR_MFA_CODE: "123456",
        OPERATOR_SESSION_SECRET: "a-production-session-secret-that-is-long-enough",
    }), false);
});
//# sourceMappingURL=operatorAuth.test.js.map