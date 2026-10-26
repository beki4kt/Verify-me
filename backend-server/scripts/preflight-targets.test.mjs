import assert from "node:assert/strict";
import test from "node:test";
import { planPreflight } from "./preflight-targets.mjs";

test("proxy preflight checks relay TLS, direct banks and Supabase without requiring Ethiopian host egress", () => {
  const plan = planPreflight({
    CHEKMI_PROVIDER_EGRESS: "proxy",
    TELEBIRR_PROXY_URLS: "https://chekmiverifier.com.et/verify.php",
    TELEBIRR_PROXY_KEY: "test-secret",
    CBE_PROXY_URL: "https://chekmiverifier.com.et/verifyCbe.php",
    CBE_PROXY_KEY: "test-secret",
    MPESA_PROXY_URL: "https://chekmiverifier.com.et/mpesa.php",
    MPESA_PROXY_KEY: "test-secret",
  }, "example.supabase.co");
  assert.equal(plan.requiresEthiopianEgress, false);
  assert.deepEqual(plan.errors, []);
  assert.ok(plan.targets.some(([, host]) => host === "chekmiverifier.com.et"));
  assert.ok(plan.targets.some(([, host]) => host === "receipt.dashensuperapp.com"));
  assert.ok(plan.targets.some(([, host]) => host === "example.supabase.co"));
  assert.ok(!plan.targets.some(([, host]) => host === "transactioninfo.ethiotelecom.et"));
  assert.ok(!JSON.stringify(plan).includes("test-secret"));
});

test("proxy preflight fails closed on missing or unsafe relay configuration", () => {
  const plan = planPreflight({ CHEKMI_PROVIDER_EGRESS: "proxy",
    TELEBIRR_PROXY_URLS: "http://relay.example/verify.php?key=secret" }, undefined);
  assert.ok(plan.errors.some(value => value.includes("TELEBIRR_PROXY_KEY")));
  assert.ok(plan.errors.some(value => value.includes("TELEBIRR_PROXY_URLS")));
  assert.ok(plan.errors.some(value => value.includes("CBE_PROXY_URL")));
  assert.ok(!JSON.stringify(plan).includes("key=secret"));
  assert.throws(() => planPreflight({ CHEKMI_PROVIDER_EGRESS: "invalid" }, undefined));
});

test("proxy preflight rejects example keys and checks a configured HTTPS port", () => {
  const plan = planPreflight({ CHEKMI_PROVIDER_EGRESS: "proxy",
    TELEBIRR_PROXY_URLS: "https://relay.example:8443/verify.php",
    TELEBIRR_PROXY_KEY: "SET_PRIVATELY_IN_PLESK",
    CBE_PROXY_URL: "https://relay.example/verifyCbe.php", CBE_PROXY_KEY: "test-secret",
    MPESA_PROXY_URL: "https://relay.example/mpesa.php", MPESA_PROXY_KEY: "test-secret",
  }, undefined);
  assert.ok(plan.errors.some(value => value.includes("TELEBIRR_PROXY_KEY")));
  assert.ok(plan.targets.some(([, host, port]) => host === "relay.example" && port === 8443));
});
