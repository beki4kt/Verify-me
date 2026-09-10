const input = process.argv[2];
if (!input) throw new Error('Usage: node scripts/check-deployment.mjs https://YOUR_APP.app.aletcloud.com');
const origin = new URL(input);
if (origin.protocol !== 'https:' || origin.username || origin.password || origin.search || origin.hash) {
  throw new Error('Provide the public HTTPS app URL without credentials, query parameters or a fragment.');
}
let failures = 0;
const expectedEngine = process.argv.includes('--engine=veritas') ? 'veritas' : null;
let activeEngine;
for (const check of [
  { path: '/health', method: 'GET', status: 200, matches: body => body.status === 'ok' },
  { path: '/ready', method: 'GET', status: 200, matches: body => {
    activeEngine = body.verifier?.engine ?? 'owned';
    console.log(`Verification engine: ${activeEngine}; mode: ${body.verifier?.mode ?? 'unknown'}`);
    return body.status === 'ready' && body.verifierMode === 'live'
      && (!expectedEngine || (activeEngine === expectedEngine && body.verifier?.imageVerification === false));
  } },
  { path: '/api/verify-and-create', method: 'POST', status: 401, matches: body => body.code === 'SESSION_REQUIRED' },
  { path: '/api/verify', method: 'POST', status: 410, matches: body => body.code === 'LEGACY_VERIFY_DISABLED' },
]) {
  try {
    const response = await fetch(new URL(check.path, origin), {
      method: check.method, redirect: 'error', signal: AbortSignal.timeout(30000),
      ...(check.method === 'POST' ? { headers: { 'content-type': 'application/json' }, body: '{}' } : {}),
    });
    const body = await response.json();
    // An optional API-key gate may reject the legacy route before its disabled handler.
    const guardedLegacy = check.path === '/api/verify' && response.status === 401 && body.code === 'UNAUTHORIZED';
    const passed = guardedLegacy || (response.status === check.status && check.matches(body));
    if (!passed) failures++;
    console.log(`${passed ? 'PASS' : 'FAIL'} ${check.method} ${check.path}: HTTP ${response.status} ${body.code || body.status || ''}`);
  } catch (error) {
    failures++;
    console.log(`FAIL ${check.path}: ${error.message}`);
  }
}
try {
  const response = await fetch(new URL('/connectivity', origin), { redirect: 'error', signal: AbortSignal.timeout(30000) });
  const body = await response.json();
  console.log(`Connectivity: ${body.status}\n${body.output || ''}`);
  if (!response.ok || (activeEngine === 'veritas' ? body.status !== 'not_applicable' : body.status !== 'passed')) failures++;
} catch (error) {
  failures++;
  console.log(`FAIL connectivity report: ${error.message}`);
}
console.log('These checks submit no receipt and create no payment. Configuration readiness is not a live database/receipt test.');
process.exitCode = failures ? 1 : 0;
