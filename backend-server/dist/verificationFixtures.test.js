"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const verificationFixtures_1 = require("./verificationFixtures");
(0, node_test_1.default)("fixture verifier is allowed only outside production", () => {
    strict_1.default.equal((0, verificationFixtures_1.resolveVerifierMode)({
        NODE_ENV: "production",
        CHEKMI_ENV: "staging",
        CHEKMI_VERIFIER_MODE: "fixtures",
    }), "fixtures");
    strict_1.default.throws(() => (0, verificationFixtures_1.resolveVerifierMode)({
        NODE_ENV: "production",
        CHEKMI_ENV: "production",
        CHEKMI_VERIFIER_MODE: "fixtures",
    }), /forbidden/);
    strict_1.default.throws(() => (0, verificationFixtures_1.resolveVerifierMode)({ CHEKMI_VERIFIER_MODE: "sometimes" }), /must be live or fixtures/);
});
(0, node_test_1.default)("successful fixtures preserve the tenant destination and expected amount", () => {
    const result = (0, verificationFixtures_1.fixtureVerification)({
        provider: "telebirr",
        reference: "chekmi-ok",
        expectedAmount: 1250,
        receivingAccount: "+251911000099",
        now: new Date("2026-08-24T10:00:00.000Z"),
    });
    strict_1.default.equal(result.ok, true);
    strict_1.default.equal(result.data?.amount, 1250);
    strict_1.default.equal(result.data?.receiverAccount, "+251911000099");
    strict_1.default.equal(result.data?.fixture, true);
});
(0, node_test_1.default)("fixtures cover tip, underpayment, wrong destination, and stale payment", () => {
    const base = {
        provider: "cbe",
        expectedAmount: 1000,
        receivingAccount: "1000000000000999",
        now: new Date("2026-08-24T10:00:00.000Z"),
    };
    const tip = (0, verificationFixtures_1.fixtureVerification)({ ...base, reference: "CHEKMI-TIP" });
    const underpaid = (0, verificationFixtures_1.fixtureVerification)({
        ...base,
        reference: "CHEKMI-UNDERPAID",
    });
    const wrongDestination = (0, verificationFixtures_1.fixtureVerification)({
        ...base,
        reference: "CHEKMI-WRONG-DEST",
    });
    const stale = (0, verificationFixtures_1.fixtureVerification)({ ...base, reference: "CHEKMI-STALE" });
    strict_1.default.equal(tip.data?.amount, 1100);
    strict_1.default.equal(underpaid.data?.amount, 750);
    strict_1.default.notEqual(wrongDestination.data?.receiverAccount, base.receivingAccount);
    strict_1.default.equal(stale.data?.txnDate, "2026-08-22T10:00:00.000Z");
});
(0, node_test_1.default)("fixture outage remains a distinct retryable provider failure", () => {
    strict_1.default.throws(() => (0, verificationFixtures_1.fixtureVerification)({
        provider: "telebirr",
        reference: "CHEKMI-OUTAGE",
        expectedAmount: 100,
        receivingAccount: "+251911000099",
    }), verificationFixtures_1.FixtureProviderUnavailableError);
});
//# sourceMappingURL=verificationFixtures.test.js.map