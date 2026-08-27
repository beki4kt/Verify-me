import assert from "node:assert/strict";
import test from "node:test";

import {
  authenticateOperator,
  hashOperatorPassword,
  operatorIsConfigured,
  totpCode,
  verifyOperatorPassword,
  verifyOperatorToken,
} from "./operatorAuth";

test("operator passwords use salted scrypt hashes", () => {
  const encoded = hashOperatorPassword("A-long-owner-password!2026", Buffer.alloc(16, 7));
  assert.equal(verifyOperatorPassword("A-long-owner-password!2026", encoded), true);
  assert.equal(verifyOperatorPassword("incorrect-password", encoded), false);
});

test("operator login validates password, MFA, and signed expiry", () => {
  const now = Date.parse("2026-08-22T08:00:00.000Z");
  const secret = "JBSWY3DPEHPK3PXP";
  const env: NodeJS.ProcessEnv = {
    NODE_ENV: "production",
    OPERATOR_EMAIL: "owner@chekmi.test",
    OPERATOR_PASSWORD_HASH: hashOperatorPassword("A-long-owner-password!2026", Buffer.alloc(16, 9)),
    OPERATOR_TOTP_SECRET: secret,
    OPERATOR_SESSION_SECRET: "a-production-session-secret-that-is-long-enough",
  };
  const login = authenticateOperator({
    email: "OWNER@CHEKMI.TEST",
    password: "A-long-owner-password!2026",
    code: totpCode(secret, now),
  }, env, now);
  assert.equal(verifyOperatorToken(login.token, env, now + 60_000).sub, "owner@chekmi.test");
  assert.throws(() => verifyOperatorToken(login.token, env, now + 3 * 60 * 60 * 1000));
});

test("production refuses plaintext or incomplete operator configuration", () => {
  assert.equal(operatorIsConfigured({
    NODE_ENV: "production",
    OPERATOR_EMAIL: "owner@chekmi.test",
    OPERATOR_PASSWORD: "plaintext",
    OPERATOR_MFA_CODE: "123456",
    OPERATOR_SESSION_SECRET: "a-production-session-secret-that-is-long-enough",
  }), false);
});
