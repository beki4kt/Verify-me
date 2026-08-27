import assert from "node:assert/strict";
import test from "node:test";

import {
  FixtureProviderUnavailableError,
  fixtureVerification,
  resolveVerifierMode,
} from "./verificationFixtures";

test("fixture verifier is allowed only outside production", () => {
  assert.equal(
    resolveVerifierMode({
      NODE_ENV: "production",
      CHEKMI_ENV: "staging",
      CHEKMI_VERIFIER_MODE: "fixtures",
    }),
    "fixtures",
  );
  assert.throws(
    () =>
      resolveVerifierMode({
        NODE_ENV: "production",
        CHEKMI_ENV: "production",
        CHEKMI_VERIFIER_MODE: "fixtures",
      }),
    /forbidden/,
  );
  assert.throws(
    () => resolveVerifierMode({ CHEKMI_VERIFIER_MODE: "sometimes" }),
    /must be live or fixtures/,
  );
});

test("successful fixtures preserve the tenant destination and expected amount", () => {
  const result = fixtureVerification({
    provider: "telebirr",
    reference: "chekmi-ok",
    expectedAmount: 1250,
    receivingAccount: "+251911000099",
    now: new Date("2026-08-24T10:00:00.000Z"),
  });

  assert.equal(result.ok, true);
  assert.equal(result.data?.amount, 1250);
  assert.equal(result.data?.receiverAccount, "+251911000099");
  assert.equal(result.data?.fixture, true);
});

test("fixtures cover tip, underpayment, wrong destination, and stale payment", () => {
  const base = {
    provider: "cbe",
    expectedAmount: 1000,
    receivingAccount: "1000000000000999",
    now: new Date("2026-08-24T10:00:00.000Z"),
  };
  const tip = fixtureVerification({ ...base, reference: "CHEKMI-TIP" });
  const underpaid = fixtureVerification({
    ...base,
    reference: "CHEKMI-UNDERPAID",
  });
  const wrongDestination = fixtureVerification({
    ...base,
    reference: "CHEKMI-WRONG-DEST",
  });
  const stale = fixtureVerification({ ...base, reference: "CHEKMI-STALE" });

  assert.equal(tip.data?.amount, 1100);
  assert.equal(underpaid.data?.amount, 750);
  assert.notEqual(wrongDestination.data?.receiverAccount, base.receivingAccount);
  assert.equal(stale.data?.txnDate, "2026-08-22T10:00:00.000Z");
});

test("fixture outage remains a distinct retryable provider failure", () => {
  assert.throws(
    () =>
      fixtureVerification({
        provider: "telebirr",
        reference: "CHEKMI-OUTAGE",
        expectedAmount: 100,
        receivingAccount: "+251911000099",
      }),
    FixtureProviderUnavailableError,
  );
});
