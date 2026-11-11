"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const demoVerification_1 = require("./demoVerification");
function setup() {
    const state = { used: 0, lookups: 0, fail: false, capacity: false };
    const requests = new Map();
    const calls = [];
    const handler = (0, demoVerification_1.createDemoVerificationHandler)({ SUPABASE_URL: 'https://db.example', SUPABASE_SERVICE_ROLE_KEY: 'secret-db', CHEKMI_BACKEND_URL: 'https://backend.example/api', CHEKMI_INTERNAL_LOOKUP_KEY: 'secret-lookup' }, (async (url, init) => {
        const path = String(url);
        const body = JSON.parse(String(init?.body));
        calls.push(path);
        let result;
        if (path.endsWith('/internal/provider-lookup')) {
            state.lookups++;
            if (state.fail)
                throw Error('private transport details');
            strict_1.default.equal(new Headers(init?.headers).get('x-chekmi-lookup-key'), 'secret-lookup');
            strict_1.default.deepEqual(body, { provider: 'telebirr', reference: 'DI82JQ406M' });
            result = { ok: true, data: { reference: 'DI82JQ406M', amount: 100, currency: 'ETB', txnDate: '2026-09-08T09:21:32.000Z', receiverAccount: '2519****7175' } };
        }
        else if (path.endsWith('demo_lookup_status'))
            result = { remaining: 10 - state.used, result: requests.get(body.p_request_id)?.result ?? null };
        else if (path.endsWith('reserve_demo_lookup')) {
            strict_1.default.match(body.p_token_hash, /^[0-9a-f]{64}$/);
            strict_1.default.notEqual(body.p_token_hash, 'a'.repeat(64));
            const old = requests.get(body.p_request_id);
            if (old)
                result = { state: old.fingerprint === body.p_fingerprint ? 'existing' : 'conflict', remaining: 10 - state.used, result: old.result };
            else if (state.used >= 10)
                result = { state: 'exhausted', remaining: 0 };
            else if (state.capacity)
                result = { state: 'capacity', remaining: 10 - state.used };
            else {
                state.used++;
                requests.set(body.p_request_id, { fingerprint: body.p_fingerprint, result: null });
                result = { state: 'reserved', remaining: 10 - state.used };
            }
        }
        else if (path.endsWith('finish_demo_lookup')) {
            requests.get(body.p_request_id).result = body.p_result;
            result = null;
        }
        else
            throw Error('Unexpected RPC ' + path);
        return new Response(JSON.stringify(result));
    }));
    const send = async (extra = {}) => {
        const response = await handler(new Request('https://db.example/functions/v1/chekmi-demo', { method: 'POST', body: JSON.stringify({ installationToken: 'a'.repeat(64), action: 'verify', lookupId: '12345678-1234-1234-1234-123456789012', provider: 'telebirr', reference: 'DI82JQ406M', ...extra }) }));
        return { status: response.status, body: await response.json() };
    };
    return { state, calls, send };
}
(0, node_test_1.default)('demo returns real normalized receipt evidence without staff login or a business payment', async () => {
    const { send, state, calls } = setup();
    const result = await send();
    strict_1.default.equal(result.body.success, true);
    strict_1.default.equal(result.body.demo, true);
    strict_1.default.equal(result.body.receipt.amount, 100);
    strict_1.default.equal(result.body.remaining, 9);
    strict_1.default.equal(state.lookups, 1);
    strict_1.default.ok(calls.every(x => !x.includes('commit_verified_payment') && !x.includes('login_staff')));
    strict_1.default.ok(!JSON.stringify(result).includes('secret-'));
    strict_1.default.ok(!JSON.stringify(result).includes('ticket_id'));
});
(0, node_test_1.default)('demo rejects the eleventh lookup and repeated request IDs do not spend another check', async () => {
    const { send, state } = setup();
    for (let i = 0; i < 10; i++) {
        const result = await send({ lookupId: `12345678-1234-1234-1234-${String(i).padStart(12, '0')}` });
        strict_1.default.equal(result.body.success, true);
    }
    strict_1.default.equal((await send()).body.code, 'DEMO_LIMIT_REACHED');
    strict_1.default.equal(state.lookups, 10);
    strict_1.default.equal((await send({ lookupId: '12345678-1234-1234-1234-000000000000' })).body.success, true);
    strict_1.default.equal(state.lookups, 10);
});
(0, node_test_1.default)('demo status is read-only and input errors do not spend an allowance', async () => {
    const { send, state } = setup();
    await send({ action: 'usage' });
    await send({ action: 'status' });
    strict_1.default.equal(state.lookups, 0);
    strict_1.default.equal((await send({ provider: 'abyssinia', receivingAccount: '' })).status, 400);
    strict_1.default.equal(state.used, 0);
    strict_1.default.equal((await send({ installationToken: 'bad' })).status, 400);
    strict_1.default.equal(state.lookups, 0);
});
(0, node_test_1.default)('failed demo lookups count once and never become fake successes', async () => {
    const { send, state } = setup();
    state.fail = true;
    const result = await send();
    strict_1.default.equal(result.body.success, false);
    strict_1.default.equal(result.body.remaining, 9);
    strict_1.default.equal((await send()).body.success, false);
    strict_1.default.equal(state.lookups, 1);
    strict_1.default.equal(state.used, 1);
});
(0, node_test_1.default)('daily demo capacity prevents a provider lookup', async () => {
    const { send, state } = setup();
    state.capacity = true;
    strict_1.default.equal((await send()).body.code, 'DEMO_LIMIT');
    strict_1.default.equal(state.lookups, 0);
    strict_1.default.equal(state.used, 0);
});
//# sourceMappingURL=demoVerification.test.js.map