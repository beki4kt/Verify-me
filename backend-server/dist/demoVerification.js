"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createDemoVerificationHandler = createDemoVerificationHandler;
const veritasProtocol_1 = require("./veritasProtocol");
const paymentSecurity_1 = require("./paymentSecurity");
const providers = new Set(['telebirr', 'cbe', 'cbebirr', 'dashen', 'abyssinia', 'mpesa']);
const hash = async (value) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map(x => x.toString(16).padStart(2, '0')).join('');
async function boundedJson(value, limit = 500000) {
    const reader = value.body?.getReader();
    if (!reader)
        throw Error('Empty response');
    let size = 0;
    const chunks = [];
    while (true) {
        const { done, value: chunk } = await reader.read();
        if (done)
            break;
        size += chunk.length;
        if (size > limit) {
            await reader.cancel();
            throw Error('Response too large');
        }
        chunks.push(chunk);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.length;
    }
    const result = JSON.parse(new TextDecoder().decode(bytes));
    if (!result || typeof result !== 'object' || Array.isArray(result))
        throw Error('Invalid JSON');
    return result;
}
function createDemoVerificationHandler(env, transport = fetch) {
    const ready = Boolean(env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY && env.VERITAS_API_KEY);
    return async (req) => {
        const requestId = crypto.randomUUID();
        const origin = req.headers.get('origin');
        const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
        if (origin) {
            if (!(env.CORS_ALLOWED_ORIGINS || '').split(',').map(x => x.trim()).includes(origin))
                return new Response('Origin not allowed', { status: 403 });
            headers['Access-Control-Allow-Origin'] = origin;
            headers.Vary = 'Origin';
            headers['Access-Control-Allow-Headers'] = 'content-type,apikey';
            headers['Access-Control-Allow-Methods'] = 'GET,POST,OPTIONS';
        }
        const reply = (status, body) => new Response(JSON.stringify({ ...body, demo: true, requestId }), { status, headers });
        if (req.method === 'OPTIONS')
            return new Response(null, { status: 204, headers });
        if (req.method === 'GET')
            return reply(ready ? 200 : 503, { status: ready ? 'ready' : 'not_ready', service: 'chekmi-demo', version: '2026-09-08.1', allowance: 10 });
        if (req.method !== 'POST')
            return reply(405, { success: false, error: 'Use POST.' });
        if (!ready)
            return reply(503, { success: false, code: 'DEMO_NOT_CONFIGURED', error: 'The demo scanner is not configured yet.' });
        const rpc = async (name, params) => {
            const response = await transport(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, { method: 'POST', headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' }, body: JSON.stringify(params), signal: AbortSignal.timeout(8000), redirect: 'error' });
            if (!response.ok)
                throw Error('Demo database unavailable');
            return await response.json();
        };
        try {
            const body = await boundedJson(req, 4096);
            if (typeof body.installationToken !== 'string' || !/^[0-9a-f]{64}$/.test(body.installationToken))
                return reply(400, { success: false, error: 'Invalid demo installation.' });
            const tokenHash = await hash(body.installationToken);
            if (body.action === 'usage' || body.action === 'status') {
                if (body.action === 'status' && !/^[0-9a-f-]{36}$/.test(body.lookupId || ''))
                    return reply(400, { success: false, error: 'Invalid demo request.' });
                const state = await rpc('demo_lookup_status', { p_token_hash: tokenHash, p_request_id: body.action === 'status' ? body.lookupId : null });
                return reply(200, { success: false, ...state, ...(state.result || {}), remaining: state.remaining });
            }
            const provider = body.provider;
            const reference = typeof body.reference === 'string' ? body.reference.trim() : '';
            if (body.action !== 'verify' || !providers.has(provider) || !reference || reference.length > 256 || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(body.lookupId || ''))
                return reply(400, { success: false, error: 'Select a payment method and enter its receipt reference.' });
            const input = { reference };
            if (provider === 'cbe' || provider === 'abyssinia') {
                const suffix = (0, paymentSecurity_1.authoritativeAccountSuffix)(body.receivingAccount, provider === 'cbe' ? 8 : 5);
                if (!suffix)
                    return reply(400, { success: false, error: 'Enter the receiving bank account shown on the receipt.' });
                input.suffix = suffix;
            }
            if (provider === 'cbebirr') {
                const phone = (0, paymentSecurity_1.authoritativeEthiopianPhone)(body.receivingAccount);
                if (!phone)
                    return reply(400, { success: false, error: 'Enter the receiving CBE Birr phone number.' });
                input.phoneNumber = phone;
            }
            const outgoing = (0, veritasProtocol_1.veritasRequest)(provider, input);
            const cap = Number(env.DEMO_DAILY_LIMIT || 100);
            const reservation = await rpc('reserve_demo_lookup', { p_token_hash: tokenHash, p_request_id: body.lookupId, p_fingerprint: await hash(JSON.stringify({ provider, ...outgoing.body })), p_daily_limit: Number.isInteger(cap) && cap > 0 && cap <= 10000 ? cap : 100 });
            const remaining = reservation.remaining;
            if (reservation.state === 'existing')
                return reply(200, { success: false, code: 'DEMO_PENDING', error: 'This demo check is still pending. Check its result shortly.', ...reservation.result, remaining });
            if (reservation.state !== 'reserved')
                return reply(429, { success: false, remaining, code: reservation.state === 'exhausted' ? 'DEMO_LIMIT_REACHED' : 'DEMO_LIMIT', error: reservation.state === 'exhausted' ? 'You have used your 10 free checks. Connect a business to continue.' : reservation.state === 'conflict' ? 'This request ID was already used for another receipt.' : 'The demo has reached its daily capacity. Try again tomorrow.' });
            let result;
            try {
                const upstream = await transport(`https://verifyapi.leulzenebe.pro${outgoing.path}`, { method: 'POST', headers: { 'x-api-key': env.VERITAS_API_KEY.trim(), 'Content-Type': 'application/json' }, body: JSON.stringify(outgoing.body), signal: AbortSignal.timeout(25000), redirect: 'error' });
                if (!upstream.ok) {
                    await upstream.body?.cancel();
                    result = { success: false, error: upstream.status === 429 ? 'The provider is busy. Try again later.' : upstream.status >= 500 ? 'The provider could not be reached. Try again later.' : 'The provider could not verify this reference.' };
                }
                else {
                    const normalized = (0, veritasProtocol_1.normalizeVeritas)(provider, outgoing.reference, await boundedJson(upstream));
                    result = normalized.ok ? { success: true, receipt: { provider, reference: normalized.data.reference, amount: normalized.data.amount, currency: normalized.data.currency, date: normalized.data.txnDate, receiverName: normalized.data.receiverName, receiverAccount: normalized.data.receiverAccount } } : { success: false, error: normalized.error };
                }
            }
            catch {
                result = { success: false, error: 'The provider did not respond in time. This lookup used one demo check.' };
            }
            await rpc('finish_demo_lookup', { p_token_hash: tokenHash, p_request_id: body.lookupId, p_result: result });
            return reply(200, { ...result, remaining });
        }
        catch {
            return reply(503, { success: false, code: 'DEMO_UNAVAILABLE', error: 'Could not confirm the demo result. Check again before starting another lookup.' });
        }
    };
}
//# sourceMappingURL=demoVerification.js.map