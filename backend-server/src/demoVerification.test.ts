import assert from 'node:assert/strict';
import test from 'node:test';
import {createDemoVerificationHandler} from './demoVerification';
function setup(){
  const state={used:0,lookups:0,fail:false,capacity:false};
  const requests=new Map<string,{fingerprint:string,result:unknown}>();
  const calls:string[]=[];
  const handler=createDemoVerificationHandler({SUPABASE_URL:'https://db.example',SUPABASE_SERVICE_ROLE_KEY:'secret-db',VERITAS_API_KEY:'secret-veritas'},(async(url,init)=>{
    const path=String(url);const body=JSON.parse(String(init?.body));calls.push(path);
    let result:unknown;
    if(path.includes('/verify-telebirr')){state.lookups++;if(state.fail)throw Error('private transport details');
      assert.deepEqual(body,{reference:'DI82JQ406M'});
      result={success:true,data:{receiptNo:'DI82JQ406M',transactionStatus:'Completed',settledAmount:'100 Birr',paymentDate:'08-09-2026 12:21:32',creditedPartyAccountNo:'2519****7175'}};
    }else if(path.endsWith('demo_lookup_status'))result={remaining:10-state.used,result:requests.get(body.p_request_id)?.result??null};
    else if(path.endsWith('reserve_demo_lookup')){
      assert.match(body.p_token_hash,/^[0-9a-f]{64}$/);assert.notEqual(body.p_token_hash,'a'.repeat(64));
      const old=requests.get(body.p_request_id);
      if(old)result={state:old.fingerprint===body.p_fingerprint?'existing':'conflict',remaining:10-state.used,result:old.result};
      else if(state.used>=10)result={state:'exhausted',remaining:0};
      else if(state.capacity)result={state:'capacity',remaining:10-state.used};
      else{state.used++;requests.set(body.p_request_id,{fingerprint:body.p_fingerprint,result:null});result={state:'reserved',remaining:10-state.used};}
    }else if(path.endsWith('finish_demo_lookup')){requests.get(body.p_request_id)!.result=body.p_result;result=null;}
    else throw Error('Unexpected RPC '+path);
    return new Response(JSON.stringify(result));
  }) as typeof fetch);
  const send=async(extra:Record<string,unknown>={})=>{
    const response=await handler(new Request('https://db.example/functions/v1/chekmi-demo',{method:'POST',body:JSON.stringify({installationToken:'a'.repeat(64),action:'verify',lookupId:'12345678-1234-1234-1234-123456789012',provider:'telebirr',reference:'DI82JQ406M',...extra})}));
    return {status:response.status,body:await response.json() as Record<string,any>};
  };
  return {state,calls,send};
}
test('demo returns real normalized receipt evidence without staff login or a business payment',async()=>{
  const {send,state,calls}=setup();const result=await send();assert.equal(result.body.success,true);assert.equal(result.body.demo,true);assert.equal(result.body.receipt.amount,100);assert.equal(result.body.remaining,9);
  assert.equal(state.lookups,1);assert.ok(calls.every(x=>!x.includes('commit_verified_payment')&&!x.includes('login_staff')));
  assert.ok(!JSON.stringify(result).includes('secret-'));assert.ok(!JSON.stringify(result).includes('ticket_id'));
});
test('demo rejects the eleventh lookup and repeated request IDs do not spend another check',async()=>{
  const {send,state}=setup();for(let i=0;i<10;i++){const result=await send({lookupId:`12345678-1234-1234-1234-${String(i).padStart(12,'0')}`});assert.equal(result.body.success,true);}
  assert.equal((await send()).body.code,'DEMO_LIMIT_REACHED');assert.equal(state.lookups,10);
  assert.equal((await send({lookupId:'12345678-1234-1234-1234-000000000000'})).body.success,true);assert.equal(state.lookups,10);
});
test('demo status is read-only and input errors do not spend an allowance',async()=>{
  const {send,state}=setup();await send({action:'usage'});await send({action:'status'});assert.equal(state.lookups,0);
  assert.equal((await send({provider:'abyssinia',receivingAccount:''})).status,400);assert.equal(state.used,0);
  assert.equal((await send({installationToken:'bad'})).status,400);assert.equal(state.lookups,0);
});
test('failed demo lookups count once and never become fake successes',async()=>{
  const {send,state}=setup();state.fail=true;const result=await send();assert.equal(result.body.success,false);assert.equal(result.body.remaining,9);
  assert.equal((await send()).body.success,false);assert.equal(state.lookups,1);assert.equal(state.used,1);
});
test('daily demo capacity prevents a provider lookup',async()=>{
  const {send,state}=setup();state.capacity=true;assert.equal((await send()).body.code,'DEMO_LIMIT');assert.equal(state.lookups,0);assert.equal(state.used,0);
});
