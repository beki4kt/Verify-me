import assert from "node:assert/strict";
import test from "node:test";
import { createEdgeVerificationHandler } from "./edgeVerification";

const env = { SUPABASE_URL: "https://database.example", SUPABASE_SERVICE_ROLE_KEY: "private-database-key", CHEKMI_BACKEND_URL: "https://backend.example/api", CHEKMI_INTERNAL_LOOKUP_KEY: "private-lookup-key" };
const receipt = (change = {}) => ({ ok: true, data: {
  reference: "DHU5AM9UB3", amount: 600, txnDate: new Date().toISOString(), status: "completed", receiverAccount: "0911000099", currency: "ETB", ...change,
} });
function setup() {
  const upstreamResponses: Response[] = [];
  const state = { calls: 0, commits: [] as Record<string, unknown>[], existing: false, upstreamStatus: 200, payload: receipt() as unknown, sessionValid: true, unavailable: false, badCommit: false, provider: "telebirr", role: "waiter", account: "0911000099", outgoing: {} as Record<string, unknown>, onUpstream: null as (() => Promise<void>) | null };
  const respond = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
  const transport = (async (input: Parameters<typeof fetch>[0], init?: RequestInit) => {
    const url = String(input); const body = JSON.parse(String(init?.body));
    if (url === 'https://backend.example/api/internal/provider-lookup') {
      state.calls++; state.outgoing = body;
      assert.equal(new Headers(init?.headers).get('x-chekmi-lookup-key'), env.CHEKMI_INTERNAL_LOOKUP_KEY);
      assert.ok(!JSON.stringify(body).includes('receiptImage'));
      assert.equal(init?.redirect, 'error');
      if (state.onUpstream) await state.onUpstream();
      if (state.unavailable) throw new DOMException('timeout', 'TimeoutError');
      return upstreamResponses.shift() ?? respond(state.payload, state.upstreamStatus);
    }
    assert.ok(url.startsWith(env.SUPABASE_URL));
    assert.equal(new Headers(init?.headers).get('apikey'), env.SUPABASE_SERVICE_ROLE_KEY);
    if (url.endsWith('/get_verification_context')) return state.sessionValid
      ? respond({ business_id: 'business-one', staff_number: '01', role: state.role, provider: state.provider, receiving_account: state.account })
      : respond({ code: '28000' }, 401);
    if (url.endsWith('/find_committed_payment')) return respond(state.existing ? { ticket_id: 'saved-one' } : null);
    if (url.endsWith('/commit_verified_payment')) {
      state.commits.push(body); if (state.badCommit) return respond({});
      state.existing = true; return respond({ ticket_id: 'saved-one', tip_amount: 0, unresolved_excess: 50, completion_status: 'marked_complete' });
    }
    if (url.endsWith('/service_record_failed_verification')) return respond(null);
    throw Error('Unexpected endpoint '+url);
  }) as typeof fetch;
  const handler = createEdgeVerificationHandler(env, transport);
  const request = (extra = {}, auth = true) => new Request('https://database.example/functions/v1/chekmi-verify', {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: 'Bearer '+'t'.repeat(64) } : {}) },
    body: JSON.stringify({ provider: state.provider, reference: 'DHU5AM9UB3', expectedAmount: 550, tableNumber: 'Invoice: INV-1042', ...extra }),
  });
  const send = async (extra = {}, auth = true) => { const r = await handler(request(extra, auth)); return { status: r.status, body: await r.json() as Record<string, any> }; };
  return { state, handler, request, send, upstreamResponses };
}

test('Edge function confirms committed payments, uses private ID lookup and recovers without a second credit', async () => {
  const { state, send } = setup();
  assert.equal((await send({}, false)).status, 401);
  assert.equal(state.calls, 0);
  const result = await send({ receiptImageBase64: 'cGhvdG8=' });
  assert.equal(result.status, 201); assert.equal(result.body.data.ticket_id, 'saved-one');
  assert.equal(result.body.data.tipAmount, 0);
  assert.equal(result.body.data.unresolvedExcess, 50);
  assert.equal(result.body.data.completion_status, 'marked_complete');
  assert.deepEqual(state.outgoing, { provider: 'telebirr', reference: 'DHU5AM9UB3' });
  assert.equal(state.commits[0].p_verified_amount, 600);
  assert.equal(state.commits[0].p_table_number, 'Invoice: INV-1042');
  assert.equal(state.commits[0].p_receipt_image_base64, null);
  assert.ok(!JSON.stringify(result).includes('private-'));
  assert.ok(!JSON.stringify(state.commits).includes('private-'));
  assert.equal((await send({ action: 'status' })).body.data.recovered, true);
  assert.equal((await send()).status, 200);
  assert.equal(state.calls, 1); assert.equal(state.commits.length, 1);
});

test('Edge accepts Telebirr middle masks, preserves masked evidence and rejects a different wallet', async () => {
  for (const account of ['0911000099', '251911000099']) {
    const {state, send} = setup(); state.account = account;
    state.payload = receipt({receiverAccount: '2519****0099'});
    assert.equal((await send()).status, 201);
    assert.equal(state.commits[0].p_receiver_account, '2519****0099');
    assert.equal(state.calls, 1);
  }
  const wrong = setup(); wrong.state.payload = receipt({receiverAccount:'2519****9999'});
  assert.equal((await wrong.send()).body.code, 'DESTINATION_MISMATCH');
  assert.equal(wrong.state.commits.length, 0);
  const otherProvider = setup(); otherProvider.state.provider = 'dashen';
  otherProvider.state.payload = receipt({receiverAccount:'2519****0099'});
  assert.equal((await otherProvider.send()).body.code, 'DESTINATION_MISMATCH');
  assert.equal(otherProvider.state.commits.length, 0);
});

test('a capability-authorized cashier verifies without a restaurant reference', async () => {
  const {state,send}=setup();
  state.role='cashier';
  const result=await send({tableNumber:''});
  assert.equal(result.status,201);
  assert.equal(state.commits[0].p_table_number,'Payment: DHU5AM9UB3');
  assert.equal(state.calls,1);
});

test('Edge status lookup never starts verification and invalid sessions cannot spend credits', async () => {
  const { state, send } = setup();
  assert.equal((await send({ action: 'status' })).body.code, 'NOT_COMMITTED');
  assert.equal(state.calls, 0);
  state.sessionValid = false;
  assert.equal((await send()).body.code, 'SESSION_EXPIRED');
  assert.equal(state.calls, 0);
});

test('Edge rejects wrong destination, underpayment, stale and mismatched receipts with no commit', async () => {
  for (const [overrides, code] of [
    [{ receiverAccount: '0911999999' }, 'DESTINATION_MISMATCH'],
    [{ amount: 500 }, 'UNDERPAID'],
    [{ txnDate: '2026-08-30T12:38:05.000Z' }, 'TRANSACTION_TOO_OLD'],
    [{ status: 'pending' }, 'NOT_VERIFIED'],
  ] as const) {
    const { state, send } = setup(); state.payload = code === 'NOT_VERIFIED' ? {ok:false,error:'The provider rejected the receipt.'} : receipt(overrides);
    const result = await send(); assert.equal(result.status, 422); assert.equal(result.body.code, code); assert.equal(state.commits.length, 0);
  }
});

test('Edge reports upstream outages and missing commit confirmations without success', async () => {
  for (const [status, code] of [[401, 'VERIFIER_CONFIGURATION_ERROR'], [429, 'PROVIDER_RATE_LIMIT'], [503, 'PROVIDER_UNAVAILABLE']] as const) {
    const { state, send } = setup(); state.upstreamStatus = status;
    const r = await send(); assert.equal(r.body.success, false); assert.equal(r.body.code, code); assert.equal(state.commits.length, 0);
  }
  const down = setup(); down.state.unavailable = true;
  assert.equal((await down.send()).body.code, 'PROVIDER_UNAVAILABLE');
  const bad = setup(); bad.state.badCommit = true;
  assert.equal((await bad.send()).body.code, 'COMMIT_NOT_CONFIRMED');
});

test('Edge recovers a transient provider gateway failure with one retry and one commit', async () => {
  const {state, send, upstreamResponses} = setup();
  upstreamResponses.push(new Response('<html>Bad gateway</html>', {status:502}));
  assert.equal((await send()).status, 201);
  assert.equal(state.calls, 2);
  assert.equal(state.commits.length, 1);
});

test('Edge bounds outage retries and preserves HTML access and rate-limit errors', async () => {
  const outage = setup(); outage.state.upstreamStatus=503;
  assert.equal((await outage.send()).body.code, 'PROVIDER_UNAVAILABLE');
  assert.equal(outage.state.calls, 2); assert.equal(outage.state.commits.length, 0);
  for (const [status, code] of [[401,'VERIFIER_CONFIGURATION_ERROR'],[429,'PROVIDER_RATE_LIMIT']] as const) {
    const one = setup(); one.upstreamResponses.push(new Response('<html>Gateway rejection</html>', {status}));
    assert.equal((await one.send()).body.code, code); assert.equal(one.state.calls, 1); assert.equal(one.state.commits.length, 0);
  }
});

test('All six provider shapes reach an atomic commit with matching trusted destinations', async () => {
  const date=new Date().toISOString();
  const samples = [
    {provider:'telebirr',reference:'DHU5AM9UB3',account:'0911000099',payload:receipt()},
    {provider:'cbe',reference:'FT1234567890',account:'1000123456789',payload:receipt({reference:'FT1234567890',receiverAccount:'1000123456789',txnDate:date})},
    {provider:'abyssinia',reference:'FT1234567890',account:'1000123456789',payload:receipt({reference:'FT1234567890',receiverAccount:null,txnDate:date})},
    {provider:'cbebirr',reference:'TX12345678',account:'0911000099',payload:receipt({reference:'TX12345678',receiverAccount:'251911000099',txnDate:date})},
    {provider:'dashen',reference:'1234567890123456',account:'0911000099',payload:receipt({reference:'1234567890123456',receiverAccount:'0911000099',txnDate:date})},
    {provider:'mpesa',reference:'TX12345678',account:'0911000099',payload:receipt({reference:'TX12345678',receiverAccount:'0911000099',txnDate:date})},
  ];
  for (const sample of samples) {
    const {state,send}=setup();Object.assign(state,{provider:sample.provider,account:sample.account,payload:sample.payload});
    const result=await send({reference:sample.reference});
    assert.equal(result.status,201,sample.provider+JSON.stringify(result.body)); assert.equal(state.commits.length,1);assert.equal(state.calls,1);
  }
});

test('Edge derives suffix from tenant and rejects a contradictory full destination', async () => {
  const { state, send } = setup(); state.provider = 'cbe'; state.account = '1000123456789';
  state.payload = receipt({reference:'FT1234567890',receiverAccount:'9999999999999'});
  const r = await send({ reference: 'FT1234567890', suffix: '99999999' });
  assert.equal(state.outgoing.suffix, '23456789');
  assert.equal(r.body.code, 'DESTINATION_MISMATCH'); assert.equal(state.commits.length, 0);
});

test('Edge coalesces concurrent duplicate submissions within the worker', async () => {
  const { state, send } = setup();
  let release!: () => void; let entered!: () => void;
  const waiting = new Promise<void>(r => { entered = r; });
  state.onUpstream = () => new Promise<void>(r => { release = r; entered(); });
  const first = send(); await waiting;
  const second = await send();
  assert.equal(second.body.code, 'VERIFICATION_IN_PROGRESS');
  release(); assert.equal((await first).status, 201); assert.equal(state.calls, 1);
});

test('Edge reports deployment readiness without revealing secrets', async () => {
  const { handler } = setup();
  const r = await handler(new Request('https://database.example/functions/v1/chekmi-verify'));
  const text = await r.text(); assert.equal(r.status, 200); assert.ok(text.includes('"engine":"owned"')); assert.ok(!text.includes('private-'));
  const missing = createEdgeVerificationHandler({});
  assert.equal((await missing(new Request('https://database.example/functions/v1/chekmi-verify'))).status, 503);
});
