"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const paymentSecurity_1 = require("./paymentSecurity");
(0, node_test_1.default)("account normalization removes payment formatting", () => {
    strict_1.default.equal((0, paymentSecurity_1.normalizeAccount)(" +251 911-222-333 "), "251911222333");
});
(0, node_test_1.default)("destination matching supports exact and masked suffix values", () => {
    strict_1.default.equal((0, paymentSecurity_1.matchesReceivingAccount)("1000123456789", "***456789"), true);
    strict_1.default.equal((0, paymentSecurity_1.matchesReceivingAccount)("+251911222333", "0911222333"), true);
    strict_1.default.equal((0, paymentSecurity_1.matchesReceivingAccount)("1000123456789", "9999456789"), false);
    strict_1.default.equal((0, paymentSecurity_1.matchesReceivingAccount)("1000123456789", "*6789"), false);
});
(0, node_test_1.default)("Abyssinia suffix is derived only from the configured business account", () => {
    strict_1.default.equal((0, paymentSecurity_1.authoritativeAbyssiniaSuffix)("1000 12345 67890"), "67890");
    strict_1.default.equal((0, paymentSecurity_1.authoritativeAbyssiniaSuffix)("1234"), null);
});
(0, node_test_1.default)("new CBE receipt masks match first character and final four digits", () => {
    strict_1.default.equal((0, paymentSecurity_1.matchesCbeReceivingAccount)("1000123456789012", "1****9012"), true);
    strict_1.default.equal((0, paymentSecurity_1.matchesCbeReceivingAccount)("1000123456789012", "1****9999"), false);
});
(0, node_test_1.default)("CBE lookup values are derived from the configured business account", () => {
    strict_1.default.equal((0, paymentSecurity_1.authoritativeAccountSuffix)("1000 1234 5678 9012", 8), "56789012");
    strict_1.default.equal((0, paymentSecurity_1.authoritativeAccountSuffix)("1234567", 8), null);
});
(0, node_test_1.default)("CBE Birr lookup uses a normalized configured Ethiopian phone", () => {
    strict_1.default.equal((0, paymentSecurity_1.authoritativeEthiopianPhone)("0911 222 333"), "251911222333");
    strict_1.default.equal((0, paymentSecurity_1.authoritativeEthiopianPhone)("0711 222 333"), "251711222333");
    strict_1.default.equal((0, paymentSecurity_1.authoritativeEthiopianPhone)("1000123456789"), null);
});
(0, node_test_1.default)("amount validation rejects client edge cases", () => {
    strict_1.default.equal((0, paymentSecurity_1.positiveAmount)("1800.50"), 1800.5);
    strict_1.default.equal((0, paymentSecurity_1.positiveAmount)(0), null);
    strict_1.default.equal((0, paymentSecurity_1.positiveAmount)(Number.NaN), null);
    strict_1.default.equal((0, paymentSecurity_1.positiveAmount)("not-money"), null);
});
(0, node_test_1.default)("transaction freshness rejects missing, stale, invalid, and future dates", () => {
    const now = new Date("2026-08-17T12:00:00.000Z");
    strict_1.default.equal((0, paymentSecurity_1.validateTransactionFreshness)("2026-08-17T11:30:00.000Z", { now }).ok, true);
    strict_1.default.equal((0, paymentSecurity_1.validateTransactionFreshness)(null, { now }).ok, false);
    strict_1.default.equal((0, paymentSecurity_1.validateTransactionFreshness)("not-a-date", { now }).ok, false);
    strict_1.default.equal((0, paymentSecurity_1.validateTransactionFreshness)("2026-08-16T11:59:00.000Z", { now }).ok, false);
    strict_1.default.equal((0, paymentSecurity_1.validateTransactionFreshness)("2026-08-17T12:11:00.000Z", { now }).ok, false);
});
//# sourceMappingURL=paymentSecurity.test.js.map