import assert from 'node:assert/strict';
import test from 'node:test';
import { stagingTargetErrors } from './check_staging_target.mjs';

const stagingRef = 'abcdefghijklmnopqrst';
const good = {
  projectRef: stagingRef,
  supabaseUrl: `https://${stagingRef}.supabase.co`,
  backendUrl: 'https://staging-api.chekmi.example/api',
  databaseUrl: `postgresql://postgres.${stagingRef}:test@aws-0-us-east-1.pooler.supabase.com:5432/postgres`,
};
test('isolated staging target is accepted', () => {
  assert.deepEqual(stagingTargetErrors(good), []);
  assert.deepEqual(stagingTargetErrors({ ...good, databaseUrl: undefined }), []);
});
test('production project, backend and database are rejected', () => {
  const errors = stagingTargetErrors({
    ...good, projectRef: 'lpbdxtzyzlaioggefscc',
    supabaseUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co',
    backendUrl: 'https://chekmi-backend-1.app.aletcloud.com/api',
    databaseUrl: 'postgresql://postgres.lpbdxtzyzlaioggefscc:test@aws-0-us-east-1.pooler.supabase.com:5432/postgres',
  });
  assert.ok(errors.length >= 3);
});
test('a staging ref with a production database is rejected', () => {
  assert.ok(stagingTargetErrors({ ...good, databaseUrl:
    'postgresql://postgres.lpbdxtzyzlaioggefscc:test@aws-0-us-east-1.pooler.supabase.com:5432/postgres' }).length);
});
test('the currently configured production API hostname is rejected', () => {
  assert.ok(stagingTargetErrors({ ...good,
    backendUrl: 'https://chekmi.app.aletcloud.com/api' }).length);
});
test('URLs with credentials, queries, or unexpected paths fail closed', () => {
  assert.ok(stagingTargetErrors({ ...good,
    supabaseUrl: `https://user:secret@${stagingRef}.supabase.co/?test=1` }).length);
  assert.ok(stagingTargetErrors({ ...good,
    backendUrl: 'https://staging-api.chekmi.example/api?mode=production' }).length);
});
