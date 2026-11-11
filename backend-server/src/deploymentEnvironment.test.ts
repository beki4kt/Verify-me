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
