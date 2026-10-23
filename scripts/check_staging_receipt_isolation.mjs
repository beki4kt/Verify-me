// Read-only two-workspace smoke. Use only with synthetic archived tickets.
import { stagingTargetErrors } from './check_staging_target.mjs';

const env = process.env;
const targetErrors = stagingTargetErrors({
  projectRef: env.STAGING_SUPABASE_PROJECT_REF,
  supabaseUrl: env.STAGING_SUPABASE_URL,
  backendUrl: env.STAGING_CHEKMI_BACKEND_URL,
  databaseUrl: env.STAGING_DATABASE_URL,
});
const required = ['STAGING_SUPABASE_PUBLISHABLE_KEY', 'STAGING_STAFF_TOKEN_A',
  'STAGING_STAFF_TOKEN_B', 'STAGING_TICKET_A', 'STAGING_TICKET_B',
  'STAGING_STORAGE_OBJECT_B'];
for (const name of required) if (!env[name]) targetErrors.push(`${name} is required.`);
if (targetErrors.length) {
  for (const error of targetErrors) console.error(`STAGING ISOLATION: ${error}`);
  process.exit(2);
}

const base = env.STAGING_SUPABASE_URL.replace(/\/$/, '');
const key = env.STAGING_SUPABASE_PUBLISHABLE_KEY;
const endpoint = `${base}/functions/v1/chekmi-receipt-evidence`;
let failed = false;
async function expectStatus(label, url, token, expected) {
  try {
    const response = await fetch(url, {
      headers: { apikey: key, authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(15000), redirect: 'error',
    });
    const ok = expected.includes(response.status);
    failed ||= !ok;
    console.log(JSON.stringify({ check: label, status: response.status, ok }));
    await response.arrayBuffer();
  } catch (error) {
    failed = true;
    console.log(JSON.stringify({ check: label, ok: false, error: error?.name || 'RequestError' }));
  }
}
const receipt = (id) => `${endpoint}?ticket=${encodeURIComponent(id)}`;
await expectStatus('A reads own original', receipt(env.STAGING_TICKET_A), env.STAGING_STAFF_TOKEN_A, [200]);
await expectStatus('B reads own original', receipt(env.STAGING_TICKET_B), env.STAGING_STAFF_TOKEN_B, [200]);
await expectStatus('A denied B original', receipt(env.STAGING_TICKET_B), env.STAGING_STAFF_TOKEN_A, [403]);
await expectStatus('B denied A original', receipt(env.STAGING_TICKET_A), env.STAGING_STAFF_TOKEN_B, [403]);
await expectStatus('invalid session denied', receipt(env.STAGING_TICKET_A), 'invalid', [401]);
const objectKey = env.STAGING_STORAGE_OBJECT_B.split('/').map(encodeURIComponent).join('/');
await expectStatus('direct anonymous Storage read denied',
  `${base}/storage/v1/object/receipt-evidence/${objectKey}`, key, [400, 401, 403, 404]);
if (failed) process.exitCode = 1;
