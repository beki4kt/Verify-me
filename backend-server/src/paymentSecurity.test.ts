import assert from "node:assert/strict";
import test from "node:test";

import {
  authoritativeAbyssiniaSuffix,
  matchesReceivingAccount,
  normalizeAccount,
  positiveAmount,
  validateTransactionFreshness,
} from "./paymentSecurity";

test("account normalization removes payment formatting", () => {
  assert.equal(normalizeAccount(" +251 911-222-333 "), "251911222333");
});

test("destination matching supports exact and masked suffix values", () => {
  assert.equal(matchesReceivingAccount("1000123456789", "***456789"), true);
  assert.equal(matchesReceivingAccount("+251911222333", "0911222333"), true);
  assert.equal(matchesReceivingAccount("1000123456789", "9999456789"), false);
  assert.equal(matchesReceivingAccount("1000123456789", "*6789"), false);
});

test("Abyssinia suffix is derived only from the configured business account", () => {
  assert.equal(authoritativeAbyssiniaSuffix("1000 12345 67890"), "67890");
  assert.equal(authoritativeAbyssiniaSuffix("1234"), null);
});

test("amount validation rejects client edge cases", () => {
  assert.equal(positiveAmount("1800.50"), 1800.5);
  assert.equal(positiveAmount(0), null);
  assert.equal(positiveAmount(Number.NaN), null);
  assert.equal(positiveAmount("not-money"), null);
});

test("transaction freshness rejects missing, stale, invalid, and future dates", () => {
  const now = new Date("2026-08-17T12:00:00.000Z");
  assert.equal(
    validateTransactionFreshness("2026-08-17T11:30:00.000Z", { now }).ok,
    true,
  );
  assert.equal(validateTransactionFreshness(null, { now }).ok, false);
  assert.equal(validateTransactionFreshness("not-a-date", { now }).ok, false);
  assert.equal(
    validateTransactionFreshness("2026-08-16T11:59:00.000Z", { now }).ok,
    false,
  );
  assert.equal(
    validateTransactionFreshness("2026-08-17T12:11:00.000Z", { now }).ok,
    false,
  );
});
