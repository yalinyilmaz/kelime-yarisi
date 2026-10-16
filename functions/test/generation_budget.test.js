import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {GenerationBudget,GENERATION_LIMITS,runBoundedBatch} from '../tools/lib/generation_budget.js';
import {callStructured} from '../src/content_generation.js';

const sources=Array.from({length:7},(_,i)=>Array.from({length:12},(_,n)=>({answerId:`word-${i}-${n}`,letterCount:i+4}))).flat();
function setup(t,limits={}) {
  const root=mkdtempSync(join(tmpdir(),'question-budget-'));
  let time=Date.parse('2026-10-15T10:00:00Z');
  const options={now:()=>time,limits:{...GENERATION_LIMITS,...limits}};
  const budget=new GenerationBudget(root,options);budget.acquire();t.after(()=>{budget.close();rmSync(root,{recursive:true,force:true});});
  return {root,budget,options,advance:ms=>{time+=ms;}};
}
const request=()=>({body:JSON.stringify({model:'gpt-6-luna',service_tier:'default',max_output_tokens:6000,input:'public evidence'})});
const endpoint='https://api.openai.com/v1/responses';
const batch=(budget,status='approved',extra={})=>runBoundedBatch({budget,sources,pool:[],limit:60,daily:true,
  select:available=>available[0],generate:async s=>({...s,review:{status}}),persist:()=>{},...extra});

test('daily run stops at 42 approvals: exactly six distinct answers per length',async t=>{
  const {budget}=setup(t);const report=await batch(budget);
  assert.equal(report.reason,'daily-target-reached');assert.equal(report.completed,42);
  assert.deepEqual(Object.values(report.approvedToday),Array(7).fill(6));
  assert.deepEqual(Object.values(report.missingToday),Array(7).fill(0));
  assert.equal(budget.attemptedIds().size,42);
});
test('all editor rejections stop after five attempts and persist across invocations and days',async t=>{
  const {root,budget,options,advance}=setup(t);const report=await batch(budget,'rejected');
  assert.equal(report.completed,5);assert.equal(report.reason,'consecutive-failures');
  budget.close();const reopened=new GenerationBudget(root,options);reopened.acquire();
  try {assert.equal((await batch(reopened)).completed,0);assert.equal(reopened.attemptedIds().size,5);}finally {reopened.close();}
  advance(86400000);const tomorrow=new GenerationBudget(root,options);tomorrow.acquire();
  try {const result=await batch(tomorrow,'rejected');assert.equal(result.completed,5);assert.equal(tomorrow.attemptedIds().size,10);}finally {tomorrow.close();}
});
test('low acceptance hits attempt limit; source shortage never triggers a retry loop',async t=>{
  const {budget}=setup(t,{attempts:8});let n=0;
  const result=await batch(budget,'approved',{generate:async s=>({...s,review:{status:++n%2?'rejected':'approved'}})});
  assert.equal(result.completed,8);assert.equal(result.reason,'attempt-limit');
  assert.equal(Object.values(result.approvedToday).reduce((a,b)=>a+b),4);
  const empty=setup(t).budget;const shortage=await batch(empty,'approved',{sources:sources.slice(0,1)});
  assert.equal(shortage.completed,1);assert.equal(shortage.reason,'source-stock-exhausted');
});
test('call cap holds even on the second request of the last allowed attempt',async t=>{
  const {budget}=setup(t,{attempts:1,calls:1});budget.begin(sources[0]);let calls=0;
  await budget.fetch(endpoint,request(),async()=>{calls++;return {};});
  budget.recordUsage({inputTokens:50,outputTokens:25});
  await assert.rejects(budget.fetch(endpoint,request(),async()=>{calls++;}),/api-call-limit/);
  assert.equal(calls,1);
});
test('daily/monthly budgets reserve before sending; insufficient funds send nothing',async t=>{
  for(const limits of [{dailyMicros:1},{monthlyMicros:1}]) {
    const {budget}=setup(t,limits);budget.begin(sources[0]);let called=false;
    await assert.rejects(budget.fetch(endpoint,request(),async()=>{called=true;}),/budget reservation/);
    assert.equal(called,false);assert.equal(budget.day.calls,0);
  }
});
test('usage settles reservation; timeout charges remain persisted and the word is quarantined',async t=>{
  const {root,budget,options}=setup(t);const attempt=budget.begin(sources[0]);
  await assert.rejects(budget.fetch(endpoint,request(),async()=>{throw new Error('timeout');}),/timeout/);
  const charged=budget.day.chargedMicros;assert(charged>0);budget.finish(attempt,'failed');budget.close();
  const next=new GenerationBudget(root,options);next.acquire();
  try {
    assert.equal(next.day.chargedMicros,charged);assert.throws(()=>next.begin(sources[0]),/already attempted/);
    next.begin(sources[1]);await next.fetch(endpoint,request(),async()=>({}));
    next.recordUsage({inputTokens:100,outputTokens:200});assert.equal(next.day.chargedMicros,charged+110);
  }finally {next.close();}
});
test('runtime and Istanbul date rollover stop before starting another request',async t=>{
  const {budget,advance}=setup(t);advance(GENERATION_LIMITS.runtimeMs);
  assert.equal((await batch(budget)).reason,'runtime-limit');assert.equal(budget.day.calls,0);
  advance(86400000);assert.equal(budget.stopReason(),'day-changed');
});
test('locks prevent concurrent spending; malformed ledgers fail closed',t=>{
  const {root,budget,options}=setup(t);const other=new GenerationBudget(root,options);
  assert.throws(()=>other.acquire(),/EEXIST/);other.close();
  assert.equal(readFileSync(budget.lock,'utf8'),`${process.pid}\n`);
  budget.close();writeFileSync(budget.file,'{"version":1,"days":{"2026-10-15":{}}}');
  assert.throws(()=>new GenerationBudget(root,options),/Invalid generation ledger/);
});
test('API failures stop batch immediately, no automatic HTTP retries',async t=>{
  const {budget}=setup(t);let calls=0;
  await assert.rejects(batch(budget,'approved',{generate:()=>callStructured({model:'gpt-6-luna',apiKey:'test-key',schema:{},name:'x',
    fetchImpl:(url,req)=>budget.fetch(url,req,async()=>{calls++;return {ok:false,status:429};}),
    onResponse:u=>budget.recordUsage(u)})}),/HTTP 429/);
  assert.equal(calls,1);assert.equal(budget.day.attempts[0].status,'failed');assert(budget.day.chargedMicros>0);
});
test('unsupported model and oversized requests are rejected without transport or switching',async t=>{
  const {budget}=setup(t);budget.begin(sources[0]);let calls=0;
  for(const body of [{model:'gpt-6-sol',service_tier:'default',max_output_tokens:6000},
    {model:'gpt-6-luna',service_tier:'default',max_output_tokens:6000,input:'x'.repeat(33000)}]) {
    await assert.rejects(budget.fetch(endpoint,{body:JSON.stringify(body)},async()=>{calls++;}));
  }
  assert.equal(calls,0);
});
test('missing usage retains conservative charge and prevents an unaccounted editor call',async t=>{
  const {budget}=setup(t);budget.begin(sources[0]);await budget.fetch(endpoint,request(),async()=>({}));
  const reserved=budget.day.chargedMicros;
  for(const usage of [{inputTokens:0,outputTokens:0},{inputTokens:0,outputTokens:20},{inputTokens:50,outputTokens:0}]) {
    budget.recordUsage(usage);assert.equal(budget.day.chargedMicros,reserved);
  }
  await assert.rejects(budget.fetch(endpoint,request(),async()=>({})),/unresolved/);
});
test('fully rejected generator/editor flow sends ten requests total, not an endless loop',async t=>{
  const {budget}=setup(t);let calls=0;
  const step=()=>callStructured({model:'gpt-6-luna',apiKey:'private-test-key',schema:{},name:'x',
    fetchImpl:(url,req)=>budget.fetch(url,req,async()=>{calls++;return {ok:true,json:async()=>({status:'completed',usage:{input_tokens:100,output_tokens:50},
      output:[{type:'message',content:[{type:'output_text',text:'{}'}]}]})};}),onResponse:u=>budget.recordUsage(u)});
  const report=await batch(budget,'rejected',{generate:async s=>{await step();await step();return {...s,review:{status:'rejected'}};}});
  assert.equal(calls,10);assert.equal(report.apiCalls,10);assert.equal(report.reason,'consecutive-failures');
  assert.equal(report.chargedOrReservedUsd,0.00035);assert(!readFileSync(budget.file,'utf8').includes('private-test-key'));
});
test('crash recovery retains reservation and monthly charges survive day rollover',async t=>{
  const {root,budget,options,advance}=setup(t);budget.begin(sources[0]);await budget.fetch(endpoint,request(),async()=>({}));
  const charge=budget.day.chargedMicros;budget.close();
  const recovered=new GenerationBudget(root,options);recovered.acquire();
  try {assert.equal(recovered.day.attempts[0].status,'failed');assert.equal(recovered.day.chargedMicros,charge);assert.equal(recovered.day.pending,null);}finally {recovered.close();}
  advance(86400000);const next=new GenerationBudget(root,options);next.acquire();
  try {assert.equal(next.day.chargedMicros,0);assert.equal(next.monthlyMicros(),charge);}finally {next.close();}
});
test('only saved main-pool approvals count toward daily target; trial approvals do not',async t=>{
  const {budget}=setup(t);
  await batch(budget,'approved',{daily:false,dailyCredit:false,limit:1,sources:sources.slice(0,1)});
  assert.equal(budget.approvedCounts()[4],0);
  await batch(budget,'approved',{daily:false,dailyCredit:true,limit:1,sources:sources.slice(1,2)});
  assert.equal(budget.approvedCounts()[4],1);
});
