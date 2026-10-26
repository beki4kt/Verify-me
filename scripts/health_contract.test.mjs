import assert from 'node:assert/strict';
import test from 'node:test';
import { healthState, verifierIsReady } from './health_contract.mjs';

test('both supported live verifier engines are healthy only when configured', () => {
  for (const engine of ['veritas', 'owned']) {
    assert.equal(verifierIsReady({ status: 'ready', verifier: { engine, configured: true } }, { ok: true }), true);
  }
  assert.equal(verifierIsReady({ status: 'ready', verifier: { engine: 'veritas', configured: false } }, { ok: true }), false);
});
test('health failures have actionable, distinct states', () => {
  assert.equal(healthState(200, true), 'ready');
  assert.equal(healthState(401, false), 'unauthorized');
  assert.equal(healthState(404, false), 'endpoint_missing');
  assert.equal(healthState(503, false), 'dependency_failure');
});
