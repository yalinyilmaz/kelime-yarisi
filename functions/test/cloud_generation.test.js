import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {CloudQuestionGenerator} from '../src/cloud_generation.js';
import {approveQuestion,reviewDigest,REVIEW_CHECKS,candidatePrompt,validateQuestion} from '../src/content.js';
import {callStructured,generateQuestion} from '../src/content_generation.js';
import {loadPublishedPool,loadPublishedSets} from '../src/published_pool.js';
import {selectSet} from '../src/set_selector.js';
import {GENERATION_LIMITS} from '../src/generation_policy.js';

// Unit adapter; real RTDB serialization/transactions are covered in emulator.integration.js.
class MemoryDatabase {
  constructor(){this.data={questionGeneration:{version:1,control:{enabled:true,projectId:'demo-kelime-yarisi'}}};}
  value(path){return path.split('/').filter(Boolean).reduce((o,k)=>o?.[k],this.data)??null;}
  put(path,value){const parts=path.split('/').filter(Boolean),last=parts.pop();let obj=this.data;for(const p of parts)obj=obj[p]??={};if(value===null)delete obj[last];else obj[last]=structuredClone(value);}
  ref(path='') {
    const db=this;
    return {get:async()=>({val:()=>structuredClone(db.value(path))}),on:(_,callback)=>callback(),off:()=>{},
      transaction:async update=>{const next=update(structuredClone(db.value(path)));if(next===undefined)return {committed:false};db.put(path,next);return {committed:true,snapshot:{val:()=>structuredClone(next)}};},
      update:async updates=>{for(const [key,value] of Object.entries(updates))db.put(`${path}/${key}`,value);}};
  }
}
const examples=JSON.parse(readFileSync(new URL('../content/examples.json',import.meta.url)));
const sources=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url))).map(q=>({...q,publication:'unpublished',review:{status:'draft'}}));
const checks=Object.fromEntries([...REVIEW_CHECKS,'hintConsistency','hintNoLeak'].map(k=>[k,true]));
const now=()=>Date.parse('2026-10-15T10:00:00Z');
function approved(source) {
  const q=approveQuestion(source,'Mock AI Turkish editor',checks,now());
  q.review={...q.review,kind:'ai-self-review',model:'gpt-6-luna',rationale:'Mock editorial audit.',sourceSupport:'Mock source support.',
    alternativesRejected:[{answer:'OTHER',reason:'Mock: distinct target meaning.'}],contentDigest:reviewDigest(q)};
  return q;
}
function setup(extra={}) {
  const database=extra.database??new MemoryDatabase();let calls=0;
  const options={database,projectId:'demo-kelime-yarisi',bundledPool:[],sources,apiKey:'private-test-key',now,
    generate:async(s,pool,o)=>{
      for(let n=0;n<2;n++)await callStructured({...o,schema:{},name:'test',input:'public-source-only'});
      return approved(s);
    },fetchImpl:async()=>{calls++;return {ok:true,json:async()=>({status:'completed',usage:{input_tokens:100,output_tokens:50},
      output:[{type:'message',content:[{type:'output_text',text:'{}'}]}]})};},...extra};
  return {database,options,job:new CloudQuestionGenerator(options),calls:()=>calls};
}
test('cloud daily target persists 42 approvals and 84 mock requests; duplicate delivery is free',async()=>{
  const {job,database,options,calls}=setup();const report=await job.run();
  assert.equal(report.reason,'daily-target-reached');assert.equal(report.apiCalls,84);assert.equal(calls(),84);
  assert.deepEqual(Object.values(report.approvedToday),Array(7).fill(6));
  assert.equal((await loadPublishedPool(database,[])).length,42);assert.equal(report.setsPublishedToday,3);
  assert.equal((await loadPublishedSets(database,[])).length,3);
  assert.equal(Object.keys(database.value('questionPool/setIndex')).length,3);
  assert.equal((await new CloudQuestionGenerator(options).run()).reason,'already-ran-today');assert.equal(calls(),84);
  assert(!JSON.stringify(database.data).includes('private-test-key'));
});
test('all cloud editorial rejections stop after five words / ten calls and never publish',async()=>{
  const {options,database,calls}=setup();const generate=options.generate;
  options.generate=async(...args)=>{const q=await generate(...args);return {...q,review:{...q.review,status:'rejected'}};};
  const report=await new CloudQuestionGenerator(options).run();
  assert.equal(report.reason,'consecutive-failures');assert.equal(report.attempts,5);assert.equal(calls(),10);
  assert.equal((await loadPublishedPool(database,[])).length,0);
  assert.equal(Object.keys(database.value('questionGeneration/rejections')).length,5);
});
test('overlapping scheduler requests acquire only one lease',async()=>{
  const {options,calls}=setup();
  const results=await Promise.all([new CloudQuestionGenerator(options).run(),new CloudQuestionGenerator(options).run()]);
  assert(results.some(r=>r.reason==='already-running'));assert.equal(calls(),84);
});
test('disabled or wrong-project controls and old events cause zero provider calls',async()=>{
  const {options,database,calls}=setup();database.put('questionGeneration/control/enabled',false);
  assert.equal((await new CloudQuestionGenerator(options).run()).reason,'disabled');
  database.put('questionGeneration/control/enabled',true);database.put('questionGeneration/control/projectId','another-project');
  assert.equal((await new CloudQuestionGenerator(options).run()).reason,'disabled');
  assert.equal((await new CloudQuestionGenerator(options).run({scheduleTime:'2026-10-14T04:00:00Z'})).reason,'stale-schedule');assert.equal(calls(),0);
});
test('cloud budget reservation and HTTP errors stop before retrying or leaking secrets',async()=>{
  const limited=setup({limits:{...GENERATION_LIMITS,dailyMicros:1}});
  const report=await limited.job.run();assert.equal(report.attempts,1);assert.equal(limited.calls(),0);assert.equal(report.reason,'generation-error');
  const failed=setup({fetchImpl:async()=>{throw new Error('private-test-key');}});
  assert.equal((await failed.job.run()).reason,'generation-error');
  const state=failed.database.value('questionGeneration');const day=state.ledger.days['2026-10-15'];
  assert.equal(day.calls,1);assert(day.chargedMicros>0);assert.equal(day.attempts[0].status,'failed');
  assert(!JSON.stringify(state).includes('private-test-key'));
});
test('empty stock reports shortage without fees; partial approvals stay private',async()=>{
  const empty=setup({sources:[]});assert.equal((await empty.job.run()).reason,'source-stock-exhausted');assert.equal(empty.calls(),0);
  const partial=setup({sources:sources.slice(0,1)});const report=await partial.job.run();
  assert.equal(report.reason,'source-stock-exhausted');assert.equal(report.apiCalls,2);
  assert.equal((await loadPublishedPool(partial.database,[])).length,0);
  assert.equal((await loadPublishedSets(partial.database,[])).length,0);
  assert.equal(Object.keys(partial.database.value('questionGeneration/draft/questions')).length,1);
});
test('publication crash leaves an outbox; duplicate invocation repairs publication without new API calls',async()=>{
  const {questions}=selectSet(examples,[],{includeExamples:true,random:()=>0.5});
  const {job,options,database,calls}=setup({sources:questions.map(q=>({...q,origin:'production',publication:'unpublished',review:{status:'draft'}}))});
  const ref=database.ref.bind(database);let fail=true;
  database.ref=(path='')=>{const r=ref(path);if(!path)r.update=async updates=>{if(fail){fail=false;throw new Error('publication interrupted');}return ref().update(updates);};return r;};
  assert.equal((await job.run()).reason,'generation-error');assert.equal(calls(),28);
  assert.equal(Object.keys(database.value('questionGeneration/outbox')).length,1);
  assert.equal((await loadPublishedPool(database,[])).length,0);
  assert.equal((await new CloudQuestionGenerator(options).run()).reason,'already-ran-today');assert.equal(calls(),28);
  assert.equal((await loadPublishedPool(database,[])).length,14);
  assert.equal((await loadPublishedSets(database,[])).length,1);
});
test('expired process lease retains unknown charges and never retries its attempted word',async()=>{
  const {job,database,options,calls}=setup({sources:sources.slice(0,1)});
  const unknown={inputBound:10000,outputLimit:6000,reservedMicros:4000};
  database.put('questionGeneration/ledger',{version:1,days:{'2026-10-14':{attempts:[{answerId:sources[0].answerId,length:4,status:'started',dailyCredit:true}],
    calls:1,chargedMicros:4000,consecutiveFailures:0,pending:unknown}}});
  database.put('questionGeneration/lease',{owner:'dead',expiresAtMs:1});
  assert.equal((await job.run()).reason,'source-stock-exhausted');assert.equal(calls(),0);
  const day=database.value('questionGeneration/ledger/days/2026-10-14');assert.equal(day.chargedMicros,4000);assert.equal(day.attempts[0].status,'failed');
  assert.equal((await new CloudQuestionGenerator(options).run()).reason,'already-ran-today');
});
test('bundled source queue has at least twelve new traceable drafts per length; none are published questions',()=>{
  const queued=JSON.parse(readFileSync(new URL('../content/source_queue.json',import.meta.url)));
  const published=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));
  assert.equal(new Set(queued.map(q=>q.answerId)).size,queued.length);
  for(let length=4;length<=10;length++)assert(queued.filter(q=>q.letterCount===length).length>=12);
  for(const q of queued){
    candidatePrompt(q);assert.deepEqual(validateQuestion({...q,clue:'Denetim amacıyla geçici açıklama.'}),[]);
    assert.equal(q.review.status,'draft');assert.equal(q.publication,'unpublished');assert(!published.some(p=>p.answerId===q.answerId));
    if(q.source.encyclopedia) {
      assert(q.source.encyclopedia.reference.includes('oldid='));assert(q.source.encyclopedia.attribution);
    } else {
      assert.equal(q.source.evidence.kind,'authored-lexical-brief');assert(q.source.evidence.reviewRequired);
      assert(q.source.reference.startsWith('https://'));assert(q.source.termsReference);assert(q.source.meaningEvidence);
    }
  }
  for(const type of ['postposition','conjunction','infinitive','postposition_phrase','verb_phrase'])assert(queued.some(q=>q.grammaticalType===type));
  assert(queued.some(q=>q.answerType==='phrase'&&q.grammaticalType==='conjunction'));
});

test('real cloud generation path publishes a conjunction and two-word verb with mock API responses',async()=>{
 const database=new MemoryDatabase();
 const queued=JSON.parse(readFileSync(new URL('../content/source_queue.json',import.meta.url)))
  .filter(q=>['VEYA','NOT TUTMAK'].includes(q.answer));
 let calls=0;
 const job=new CloudQuestionGenerator({database,projectId:'demo-kelime-yarisi',bundledPool:[],sources:queued,
  apiKey:'private-test-key',model:'gpt-6-luna',now,generate:generateQuestion,fetchImpl:async(_url,request)=>{
   calls++;const body=JSON.parse(request.body);
   const value=body.text.format.name==='turkish_question_candidates'?
    {meaning:'Test kaynağındaki hedef anlam.',candidates:(body.input.includes('Cevap: VEYA')?
      ['İki seçenek arasında tercih ilişkisi kuran bağlayıcı.', 'Alternatiflerden birini seçmeyi belirten söz.', 'Seçim yaparken iki olasılığı birbirine bağlayan kelime.']:
      ['Dinlenenlerin önemli kısımlarını kısa satırlara kaydetme eylemi.', 'Dersi sonradan hatırlamak üzere ana bilgileri deftere geçirme.', 'Konuşmadaki temel noktaları unutmamak amacıyla kâğıda aktarma.']).map(clue=>({clue,hints:['Eğitimde de kullanılabilir.','Bir ders sırasında bu kullanım görülebilir.'],hintEvidence:'Test kaynağında örneklenen kullanım.'}))}:
    {decision:'approve',selectedIndex:0,checks,rationale:'Test hedef anlamına uygun.',sourceSupport:'Yalnız test kaynağına dayanır.',alternativesRejected:[],acceptedAnswers:[]};
   return {ok:true,json:async()=>({id:'test-response',model:'gpt-6-luna',status:'completed',usage:{input_tokens:100,output_tokens:50},
    output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(value)}]}]})};
  }});
 const report=await job.run();assert.equal(report.reason,'source-stock-exhausted');assert.equal(calls,4);
 assert.equal((await loadPublishedPool(database,[])).length,0);
 const drafts=Object.values(database.value('questionGeneration/draft/questions')).map(JSON.parse);
 assert.equal(drafts.length,2);assert(drafts.some(q=>q.answer==='NOT TUTMAK'&&q.letterCount===9));
 assert(drafts.every(q=>q.review.alternativePolicy==='allow-synonyms'&&q.hints?.length===2&&q.source.hintEvidence));
});

test('an unfinished draft resumes on the next day without regenerating its accepted questions',async()=>{
 const {questions}=selectSet(examples,[],{includeExamples:true,random:()=>0.5});
 const candidates=questions.map(q=>({...q,origin:'production',publication:'unpublished',review:{status:'draft'}}));
 const {job,options,database,calls}=setup({sources:candidates,limits:{...GENERATION_LIMITS,attempts:10}});
 assert.equal((await job.run()).reason,'attempt-limit');assert.equal(calls(),20);
 const id=database.value('questionGeneration/draft/id');
 assert.equal(Object.keys(database.value('questionGeneration/draft/questions')).length,10);
 assert.equal((await loadPublishedPool(database,[])).length,0);
 const report=await new CloudQuestionGenerator({...options,now:()=>now()+86400000,limits:GENERATION_LIMITS}).run();
 assert.equal(report.setsPublishedToday,1);assert.equal(calls(),28);
 const [set]=await loadPublishedSets(database,[]);assert.equal(set.id,id);assert.equal(set.questions.length,14);
 assert.equal(database.value('questionGeneration/draft'),null);
});

test('a rejected question is replaced while only complete sets reach publication',async()=>{
 const {options,database}=setup();const generate=options.generate;let first=true;
 options.generate=async(...args)=>{const q=await generate(...args);if(first){first=false;return {...q,review:{...q.review,status:'rejected'}};}return q;};
 const report=await new CloudQuestionGenerator(options).run();
 assert.equal(report.setsPublishedToday,3);assert.equal(report.apiCalls,86);
 const published=await loadPublishedPool(database,[]);assert.equal(published.length,42);
 const rejected=Object.values(database.value('questionGeneration/rejections')).map(JSON.parse);
 assert.equal(rejected.length,1);assert(!published.some(q=>q.id===rejected[0].id));
});
