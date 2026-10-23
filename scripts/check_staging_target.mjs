import { pathToFileURL } from 'node:url';

const productionRef = 'lpbdxtzyzlaioggefscc';
const productionBackends = new Set(['chekmi.app.aletcloud.com',
  'chekmi-backend-1.app.aletcloud.com']);

export function stagingTargetErrors({ projectRef, supabaseUrl, backendUrl, databaseUrl }) {
  const errors = [];
  if (!/^[a-z0-9]{20}$/.test(projectRef || '') || projectRef === productionRef) {
    errors.push('A distinct 20-character staging project ref is required.');
  }
  let supabase;
  let backend;
  let database;
  try { supabase = new URL(supabaseUrl); } catch { errors.push('Staging Supabase URL is invalid.'); }
  try { backend = new URL(backendUrl); } catch { errors.push('Staging backend URL is invalid.'); }
  if (databaseUrl) {
    try { database = new URL(databaseUrl); } catch { errors.push('Staging database URL is invalid.'); }
  }
  if (supabase && (supabase.protocol !== 'https:' || supabase.hostname !== `${projectRef}.supabase.co` ||
      supabase.port || supabase.username || supabase.password || supabase.search || supabase.hash || supabase.pathname !== '/')) {
    errors.push('Supabase URL must identify the staging project.');
  }
  if (backend && (backend.protocol !== 'https:' || productionBackends.has(backend.hostname) ||
      backend.username || backend.password || backend.search || backend.hash || backend.pathname !== '/api')) {
    errors.push('A dedicated HTTPS staging backend /api URL is required.');
  }
  const directDatabase = database?.hostname === `db.${projectRef}.supabase.co`;
  const pooledDatabase = database?.hostname.endsWith('.pooler.supabase.com') &&
    decodeURIComponent(database.username) === `postgres.${projectRef}`;
  if (database && (
      !['postgres:', 'postgresql:'].includes(database.protocol) ||
      database.href.includes(productionRef) ||
      !(directDatabase || pooledDatabase))) {
    errors.push('Database URL must identify the staging project and never production.');
  }
  return errors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const errors = stagingTargetErrors({
    projectRef: process.env.STAGING_SUPABASE_PROJECT_REF,
    supabaseUrl: process.env.STAGING_SUPABASE_URL,
    backendUrl: process.env.STAGING_CHEKMI_BACKEND_URL,
    databaseUrl: process.env.STAGING_DATABASE_URL,
  });
  for (const error of errors) console.error(`STAGING CONFIG: ${error}`);
  if (errors.length) process.exitCode = 1;
  else console.log('Staging target validated; no production project or backend selected.');
}
