import assert from 'node:assert/strict';
import test from 'node:test';
import { validateBackendEnvironment } from './deploymentEnvironment';

const staging = 'abcdefghijklmnopqrst';
test('staging backend requires its own project', () => {
  assert.doesNotThrow(() => validateBackendEnvironment({ CHEKMI_ENV: 'staging',
    CHEKMI_STAGING_PROJECT_REF: staging, SUPABASE_URL: `https://${staging}.supabase.co`,
    SUPABASE_SERVICE_ROLE_KEY: 'test-only' }));
  assert.throws(() => validateBackendEnvironment({ CHEKMI_ENV: 'staging',
    CHEKMI_STAGING_PROJECT_REF: staging,
    SUPABASE_URL: 'https://lpbdxtzyzlaioggefscc.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-only' }));
  assert.throws(() => validateBackendEnvironment({ CHEKMI_ENV: 'staging',
    CHEKMI_STAGING_PROJECT_REF: 'lpbdxtzyzlaioggefscc',
    SUPABASE_URL: 'https://lpbdxtzyzlaioggefscc.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-only' }));
});

test('owned production backend rejects published example keys and short lookup keys', () => {
  const base = { CHEKMI_ENV: 'production', CHEKMI_VERIFICATION_ENGINE: 'owned',
    SUPABASE_URL: 'https://lpbdxtzyzlaioggefscc.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service-only',
    CHEKMI_INTERNAL_LOOKUP_KEY: 'a'.repeat(48) };
  assert.doesNotThrow(() => validateBackendEnvironment(base));
  assert.throws(() => validateBackendEnvironment({ ...base,
    SUPABASE_SERVICE_ROLE_KEY: 'SET_PRIVATELY_IN_PLESK' }));
  assert.throws(() => validateBackendEnvironment({ ...base,
    CHEKMI_INTERNAL_LOOKUP_KEY: 'SET_PRIVATELY_IN_PLESK_AND_SUPABASE_EDGE' }));
  assert.throws(() => validateBackendEnvironment({ ...base,
    CHEKMI_INTERNAL_LOOKUP_KEY: 'short' }));
});
