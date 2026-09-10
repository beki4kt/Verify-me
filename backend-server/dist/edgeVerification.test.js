"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const edgeVerification_1 = require("./edgeVerification");
const env = { SUPABASE_URL: "https://database.example", SUPABASE_SERVICE_ROLE_KEY: "private-database-key", VERITAS_API_KEY: "private-veritas-key" };
const receipt = (change = {}) => ({ success: true, data: {
        receiptNo: "DHU5AM9UB3", settledAmount: "600.00", paymentDate: new Date().toISOString(), transactionStatus: "Completed", creditedPartyAccountNo: "0911000099", ...change,
    } });
function setup() {
    const upstreamResponses = [];
    const state = { calls: 0, commits: [], existing: false, upstreamStatus: 200, payload: receipt(), sessionValid: true, unavailable: false, badCommit: false, provider: "telebirr", account: "0911000099", outgoing: {}, onUpstream: null };
    const respond = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
    const transport = (async (input, init) => {
        const url = String(input);
        const body = JSON.parse(String(init?.body));
        if (url.startsWith('https://verifyapi.leulzenebe.pro/verify-')) {
            state.calls++;
            state.outgoing = body;
            strict_1.default.equal(new Headers(init?.headers).get('x-api-key'), env.VERITAS_API_KEY);
            strict_1.default.ok(!JSON.stringify(body).includes('receiptImage'));
            strict_1.default.equal(init?.redirect, 'error');
            if (state.onUpstream)
                await state.onUpstream();
            if (state.unavailable)
                throw new DOMException('timeout', 'TimeoutError');
            return upstreamResponses.shift() ?? respond(state.payload, state.upstreamStatus);
        }
        strict_1.default.ok(url.startsWith(env.SUPABASE_URL));
        strict_1.default.equal(new Headers(init?.headers).get('apikey'), env.SUPABASE_SERVICE_ROLE_KEY);
        if (url.endsWith('/get_verification_context'))
            return state.sessionValid
                ? respond({ business_id: 'business-one', staff_number: '01', role: 'waiter', provider: state.provider, receiving_account: state.account })
                : respond({ code: '28000' }, 401);
        if (url.endsWith('/find_committed_payment'))
            return respond(state.existing ? { ticket_id: 'saved-one' } : null);
        if (url.endsWith('/commit_verified_payment')) {
            state.commits.push(body);
            if (state.badCommit)
                return respond({});
            state.existing = true;
            return respond({ ticket_id: 'saved-one' });
        }
        if (url.endsWith('/service_record_failed_verification'))
            return respond(null);
        throw Error('Unexpected endpoint ' + url);
    });
    const handler = (0, edgeVerification_1.createEdgeVerificationHandler)(env, transport);
    const request = (extra = {}, auth = true) => new Request('https://database.example/functions/v1/chekmi-verify', {
        method: 'POST', headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: 'Bearer ' + 't'.repeat(64) } : {}) },
        body: JSON.stringify({ provider: state.provider, reference: 'DHU5AM9UB3', expectedAmount: 550, tableNumber: 'Invoice: INV-1042', ...extra }),
    });
    const send = async (extra = {}, auth = true) => { const r = await handler(request(extra, auth)); return { status: r.status, body: await r.json() }; };
    return { state, handler, request, send, upstreamResponses };
}
(0, node_test_1.default)('Edge function confirms committed payments, uses private ID lookup and recovers without a second credit', async () => {
    const { state, send } = setup();
    strict_1.default.equal((await send({}, false)).status, 401);
    strict_1.default.equal(state.calls, 0);
    const result = await send({ receiptImageBase64: 'cGhvdG8=' });
    strict_1.default.equal(result.status, 201);
    strict_1.default.equal(result.body.data.ticket_id, 'saved-one');
    strict_1.default.deepEqual(state.outgoing, { reference: 'DHU5AM9UB3' });
    strict_1.default.equal(state.commits[0].p_verified_amount, 600);
    strict_1.default.equal(state.commits[0].p_table_number, 'Invoice: INV-1042');
    strict_1.default.ok(!JSON.stringify(result).includes('private-'));
    strict_1.default.ok(!JSON.stringify(state.commits).includes('private-'));
    strict_1.default.equal((await send({ action: 'status' })).body.data.recovered, true);
    strict_1.default.equal((await send()).status, 200);
    strict_1.default.equal(state.calls, 1);
    strict_1.default.equal(state.commits.length, 1);
});
(0, node_test_1.default)('Edge accepts Telebirr middle masks, preserves masked evidence and rejects a different wallet', async () => {
    for (const account of ['0911000099', '251911000099']) {
        const { state, send } = setup();
        state.account = account;
        state.payload = receipt({ creditedPartyAccountNo: '2519****0099' });
        strict_1.default.equal((await send()).status, 201);
        strict_1.default.equal(state.commits[0].p_receiver_account, '2519****0099');
        strict_1.default.equal(state.calls, 1);
    }
    const wrong = setup();
    wrong.state.payload = receipt({ creditedPartyAccountNo: '2519****9999' });
    strict_1.default.equal((await wrong.send()).body.code, 'DESTINATION_MISMATCH');
    strict_1.default.equal(wrong.state.commits.length, 0);
    const otherProvider = setup();
    otherProvider.state.provider = 'dashen';
    otherProvider.state.payload = receipt({ creditedPartyAccountNo: '2519****0099' });
    strict_1.default.equal((await otherProvider.send()).body.code, 'DESTINATION_MISMATCH');
    strict_1.default.equal(otherProvider.state.commits.length, 0);
});
(0, node_test_1.default)('Edge status lookup never starts verification and invalid sessions cannot spend credits', async () => {
    const { state, send } = setup();
    strict_1.default.equal((await send({ action: 'status' })).body.code, 'NOT_COMMITTED');
    strict_1.default.equal(state.calls, 0);
    state.sessionValid = false;
    strict_1.default.equal((await send()).body.code, 'SESSION_EXPIRED');
    strict_1.default.equal(state.calls, 0);
});
(0, node_test_1.default)('Edge rejects wrong destination, underpayment, stale and mismatched receipts with no commit', async () => {
    for (const [overrides, code] of [
        [{ creditedPartyAccountNo: '0911999999' }, 'DESTINATION_MISMATCH'],
        [{ settledAmount: '500' }, 'UNDERPAID'],
        [{ paymentDate: '2026-08-30T12:38:05.000Z' }, 'TRANSACTION_TOO_OLD'],
        [{ receiptNo: 'OTHER12345' }, 'NOT_VERIFIED'],
        [{ transactionStatus: 'Pending' }, 'NOT_VERIFIED'],
    ]) {
        const { state, send } = setup();
        state.payload = receipt(overrides);
        const result = await send();
        strict_1.default.equal(result.status, 422);
        strict_1.default.equal(result.body.code, code);
        strict_1.default.equal(state.commits.length, 0);
    }
});
(0, node_test_1.default)('Edge reports upstream outages and missing commit confirmations without success', async () => {
    for (const [status, code] of [[401, 'VERITAS_ACCESS_DENIED'], [402, 'VERITAS_CREDITS_EXHAUSTED'], [429, 'VERITAS_RATE_LIMIT'], [503, 'VERITAS_UNAVAILABLE']]) {
        const { state, send } = setup();
        state.upstreamStatus = status;
        const r = await send();
        strict_1.default.equal(r.body.success, false);
        strict_1.default.equal(r.body.code, code);
        strict_1.default.equal(state.commits.length, 0);
    }
    const down = setup();
    down.state.unavailable = true;
    strict_1.default.equal((await down.send()).body.code, 'VERITAS_UNAVAILABLE');
    const bad = setup();
    bad.state.badCommit = true;
    strict_1.default.equal((await bad.send()).body.code, 'COMMIT_NOT_CONFIRMED');
});
(0, node_test_1.default)('Edge recovers a transient provider gateway failure with one retry and one commit', async () => {
    const { state, send, upstreamResponses } = setup();
    upstreamResponses.push(new Response('<html>Bad gateway</html>', { status: 502 }));
    strict_1.default.equal((await send()).status, 201);
    strict_1.default.equal(state.calls, 2);
    strict_1.default.equal(state.commits.length, 1);
});
(0, node_test_1.default)('Edge bounds outage retries and preserves HTML access and rate-limit errors', async () => {
    const outage = setup();
    outage.state.upstreamStatus = 503;
    strict_1.default.equal((await outage.send()).body.code, 'VERITAS_UNAVAILABLE');
    strict_1.default.equal(outage.state.calls, 2);
    strict_1.default.equal(outage.state.commits.length, 0);
    for (const [status, code] of [[401, 'VERITAS_ACCESS_DENIED'], [402, 'VERITAS_CREDITS_EXHAUSTED'], [429, 'VERITAS_RATE_LIMIT']]) {
        const one = setup();
        one.upstreamResponses.push(new Response('<html>Gateway rejection</html>', { status }));
        strict_1.default.equal((await one.send()).body.code, code);
        strict_1.default.equal(one.state.calls, 1);
        strict_1.default.equal(one.state.commits.length, 0);
    }
});
(0, node_test_1.default)('All six provider shapes reach an atomic commit with matching trusted destinations', async () => {
    const date = new Date().toISOString();
    const samples = [
        { provider: 'telebirr', reference: 'DHU5AM9UB3', account: '0911000099', payload: receipt() },
        { provider: 'cbe', reference: 'FT1234567890', account: '1000123456789', payload: { success: true, reference: 'FT1234567890', amount: 600, paymentDate: date, receiverAccount: '1000123456789' } },
        { provider: 'abyssinia', reference: 'FT1234567890', account: '1000123456789', payload: { success: true, data: { header: { status: 'success' }, body: [{ 'Transaction Reference': 'FT1234567890', 'Transferred Amount': '600.00', 'Transaction Date': date }] } } },
        { provider: 'cbebirr', reference: 'TX12345678', account: '0911000099', payload: { receiptNumber: 'TX12345678', transactionStatus: 'Completed', amount: '600.00', transactionDate: date, creditAccount: '251911000099' } },
        { provider: 'dashen', reference: '1234567890123456', account: '0911000099', payload: { success: true, transactionReference: '1234567890123456', transactionAmount: 600, transactionDate: date, phoneNo: '0911000099' } },
        { provider: 'mpesa', reference: 'TX12345678', account: '0911000099', payload: { success: true, transactionId: 'TX12345678', amount: 600, paymentDate: date, receiverAccount: '0911000099' } },
    ];
    for (const sample of samples) {
        const { state, send } = setup();
        Object.assign(state, { provider: sample.provider, account: sample.account, payload: sample.payload });
        const result = await send({ reference: sample.reference });
        strict_1.default.equal(result.status, 201, sample.provider + JSON.stringify(result.body));
        strict_1.default.equal(state.commits.length, 1);
        strict_1.default.equal(state.calls, 1);
    }
});
(0, node_test_1.default)('Edge derives suffix from tenant and rejects a contradictory full destination', async () => {
    const { state, send } = setup();
    state.provider = 'cbe';
    state.account = '1000123456789';
    state.payload = { success: true, reference: 'FT1234567890', amount: 600, date: new Date().toISOString(), receiverAccount: '9999999999999' };
    const r = await send({ reference: 'FT1234567890', suffix: '99999999' });
    strict_1.default.equal(state.outgoing.accountSuffix, '23456789');
    strict_1.default.equal(r.body.code, 'DESTINATION_MISMATCH');
    strict_1.default.equal(state.commits.length, 0);
});
(0, node_test_1.default)('Edge coalesces concurrent duplicate submissions within the worker', async () => {
    const { state, send } = setup();
    let release;
    let entered;
    const waiting = new Promise(r => { entered = r; });
    state.onUpstream = () => new Promise(r => { release = r; entered(); });
    const first = send();
    await waiting;
    const second = await send();
    strict_1.default.equal(second.body.code, 'VERIFICATION_IN_PROGRESS');
    release();
    strict_1.default.equal((await first).status, 201);
    strict_1.default.equal(state.calls, 1);
});
(0, node_test_1.default)('Edge reports deployment readiness without revealing secrets', async () => {
    const { handler } = setup();
    const r = await handler(new Request('https://database.example/functions/v1/chekmi-verify'));
    const text = await r.text();
    strict_1.default.equal(r.status, 200);
    strict_1.default.ok(text.includes('"engine":"veritas"'));
    strict_1.default.ok(!text.includes('private-'));
    const missing = (0, edgeVerification_1.createEdgeVerificationHandler)({});
    strict_1.default.equal((await missing(new Request('https://database.example/functions/v1/chekmi-verify'))).status, 503);
});
//# sourceMappingURL=edgeVerification.test.js.map