import {test, after} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeApp as adminInitialize, deleteApp as adminDelete} from 'firebase-admin/app';
import {getDatabase as adminDatabase} from 'firebase-admin/database';
import {initializeApp, deleteApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInAnonymously} from 'firebase/auth';
import {connectDatabaseEmulator, getDatabase, get, goOffline, ref, set, update} from 'firebase/database';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';
import {QuestionService} from '../src/question_service.js';
import {roomKey} from '../src/allocation.js';
import {CloudQuestionGenerator} from '../src/cloud_generation.js';
import {loadPublishedPool} from '../src/published_pool.js';
import {callStructured} from '../src/content_generation.js';
import {RaceService} from '../src/race.js';
import {approveQuestion,reviewDigest,REVIEW_CHECKS} from '../src/content.js';

const projectId = 'demo-kelime-yarisi';
if (process.env.GCLOUD_PROJECT !== projectId || !process.env.FIREBASE_DATABASE_EMULATOR_HOST?.startsWith('127.0.0.1:')) {
  throw new Error('This test may run only inside the demo project emulator.');
}
const databaseURL = `https://${projectId}-default-rtdb.firebaseio.com`;
const admin = adminInitialize({projectId, databaseURL}, 'integration');
const db = adminDatabase(admin);
const pool = JSON.parse(readFileSync(new URL('../content/published.json', import.meta.url)));
const clients = [];
after(async () => {
  clients.forEach(c => goOffline(c.database));
  db.goOffline();
  await Promise.all(clients.map(c => deleteApp(c.app)));
  await adminDelete(admin);
});
async function client(name) {
  const app = initializeApp({apiKey: 'fake-api-key', projectId, databaseURL}, name);
  const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const database = getDatabase(app); connectDatabaseEmulator(database, '127.0.0.1', 9000);
  const functions = getFunctions(app, 'europe-west1'); connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  const uid = (await signInAnonymously(auth)).user.uid;
  const result = {app, uid, database, functions}; clients.push(result); return result;
}
const player = (uid, isHost) => ({displayName: uid.slice(0, 12), isHost, isReady: true, isOnline: true, lastSeenAt: Date.now()});
async function room(id, users, mode = 'classic') {
  const value = {name: 'Havuz testi', code: `${id.slice(0,3)}-${id.slice(3)}`.toUpperCase(), hostId: users[0].uid,
    targetPlayerCount: users.length, playerCount: users.length, gameMode: mode, status: 'lobby', createdAt: Date.now(),
    questionEngine: 'pool-v1', players: Object.fromEntries(users.map((u, i) => [u.uid, player(u.uid, i === 0)]))};
  await db.ref(`rooms/${id}`).set(value); return value;
}
const empty = {seenAnswerIds: [], seenQuestionIds: []};

test('cloud generator uses real RTDB leases/counters, private publication and dynamic game pool with mock provider only',async()=>{
  await db.ref().set(null);
  const sources=JSON.parse(readFileSync(new URL('../content/source_queue.json',import.meta.url)));
  const source=sources.find(q=>q.answer==='HAVUÇ')??JSON.parse(readFileSync(new URL('../../content/trial_sources.json',import.meta.url))).find(q=>q.answer==='HAVUÇ');
  await db.ref('questionGeneration/control').set({enabled:true,projectId});
  let calls=0;
  const settings={database:db,projectId,bundledPool:pool,sources:[source],apiKey:'mock-provider-key',
    fetchImpl:async()=>{calls++;return {ok:true,json:async()=>({status:'completed',usage:{input_tokens:100,output_tokens:50},
      output:[{type:'message',content:[{type:'output_text',text:'{}'}]}]})};},
    generate:async(s,p,options)=>{
      for(let i=0;i<2;i++)await callStructured({...options,schema:{},name:'mock',input:'public test evidence'});
      const q=approveQuestion({...s,clue:'Turuncu kökü besin olarak tüketilen, yaygın yetiştirilen sebze.'},'Mock editor',Object.fromEntries(REVIEW_CHECKS.map(k=>[k,true])));
      q.review={...q.review,kind:'ai-self-review',model:'gpt-6-luna',rationale:'Mock approval.',sourceSupport:'Mock support.',
        alternativesRejected:[{answer:'TURP',reason:'Mock: different vegetable.'}],contentDigest:reviewDigest(q)};
      return q;
    }};
  const jobs=[new CloudQuestionGenerator(settings),new CloudQuestionGenerator(settings)];
  const results=await Promise.all(jobs.map(job=>job.run()));
  assert(results.some(r=>r.reason==='source-stock-exhausted'),JSON.stringify({results,errors:jobs.map(j=>j.failure?.message)}));assert(results.some(r=>['already-running','already-ran-today'].includes(r.reason)));
  assert.equal(calls,2);assert.equal((await new CloudQuestionGenerator(settings).run()).reason,'already-ran-today');assert.equal(calls,2);
  assert.equal((await loadPublishedPool(db,pool)).length,pool.length+1);
  const host=await client('cloud-host'),guest=await client('cloud-guest');
  for(const path of ['questionGeneration','questionPool/published','questionSources']) {
    await assert.rejects(get(ref(host.database,path)));await assert.rejects(set(ref(host.database,path),{forged:true}));
  }
  await room('abc234',[host,guest]);
  const report=(await httpsCallable(host.functions,'prepareQuestionHistory')({roomId:'abc234',history:empty})).data;
  const bundledFive = new Set(pool.filter(q => q.letterCount === 5).map(q => q.answerId)).size;
  assert.equal(report.groups.find(g=>g.length===5).publishedAnswers,bundledFive + 1);
});

test('callable auth, shared 14-question snapshot, guest history exclusion, no metadata forgery', async () => {
  await db.ref().set(null);
  const host = await client('host'), guest = await client('guest'), outsider = await client('outsider');
  await room('abc234', [host, guest]);
  const prepare = u => httpsCallable(u.functions, 'prepareQuestionHistory');
  await prepare(host)({roomId: 'abc234', history: empty});
  await prepare(guest)({roomId: 'abc234', history: {seenAnswerIds: [pool[0].answerId], seenQuestionIds: [pool[1].id]}});
  await assert.rejects(httpsCallable(outsider.functions, 'startQuestionGame')({roomId: 'abc234'}), e => e.code === 'functions/permission-denied');
  await assert.rejects(httpsCallable(guest.functions, 'startQuestionGame')({roomId: 'abc234'}), e => e.code === 'functions/permission-denied');
  await assert.rejects(update(ref(host.database, 'rooms/abc234'), {questionSetId:'classic-v1', gameplayVersion:'sync-v1', startsAtMs:Date.now()+4000, status:'countdown'}));
  const results = await Promise.all(Array.from({length: 5}, () => httpsCallable(host.functions, 'startQuestionGame')({roomId: 'abc234'})));
  assert.equal(new Set(results.map(r => r.data.sessionId)).size, 1);
  const h = (await get(ref(host.database, 'rooms/abc234'))).val();
  const g = (await get(ref(guest.database, 'rooms/abc234'))).val();
  assert.deepEqual(h.questions, g.questions);
  assert.equal(h.questions.length, 14);
  assert.equal(h.questionOrigin, 'production');
  assert.equal(h.gameplayVersion, 'race-v1');
  assert.equal(h.race.questionIndex, 0);
  assert(!h.questions.some(q => [pool[0].answerId,pool[1].answerId].includes(q.answerId)));
  await assert.rejects(set(ref(host.database, 'rooms/abc234/questions/0/answer'), 'HİLE'));
  await assert.rejects(get(ref(host.database, 'questionPreparations')));
  await assert.rejects(get(ref(guest.database, 'questionAllocations')));
  assert.equal((await db.ref(`questionPreparations/${guest.uid}`).get()).exists(), false);
  const badRoom = {name:'Hile',code:'DEF-234',hostId:host.uid,targetPlayerCount:2,playerCount:1,gameMode:'classic',status:'lobby',createdAt:Date.now(),players:{[host.uid]:player(host.uid,true)},questions:h.questions};
  await assert.rejects(set(ref(host.database, 'rooms/def234'),badRoom));
  const unauth = initializeApp({apiKey:'fake-api-key',projectId},'unauth');
  const fn=getFunctions(unauth,'europe-west1');connectFunctionsEmulator(fn,'127.0.0.1',5001);
  await assert.rejects(httpsCallable(fn,'prepareQuestionHistory')({roomId:'abc234',history:empty}),e=>e.code==='functions/unauthenticated');
  await deleteApp(unauth);
});

test('race callables atomically select one winner, block direct forgery and advance all clients after reveal', async () => {
  await db.ref().set(null);
  const host = await client('race-host'), guest = await client('race-guest'), outsider = await client('race-outsider');
  await room('abc234', [host,guest]);
  const questions = JSON.parse(readFileSync(new URL('../content/demo.json', import.meta.url))).filter((_,i)=>i%2===0);
  await db.ref('rooms/abc234').update({status:'playing',questions,gameplayVersion:'race-v1',
    startsAtMs:Date.now()-100, race:{questionIndex:0,startedAtMs:Date.now()-100}});
  const play = (user, data) => httpsCallable(user.functions,'playRace')({roomId:'abc234',...data});
  await assert.rejects(play(outsider,{action:'answer',questionIndex:0,input:'kapi'}),e=>e.code==='functions/permission-denied');
  await assert.rejects(play(host,{action:'answer',questionIndex:0,input:{toString:'KAPI'}}),e=>e.code==='functions/invalid-argument');
  for (const [path,value] of [['race/winnerId',host.uid],['progress/'+host.uid,{score:9999}],['hints/0',{questionIndex:0,revealedCount:1}],['status','results']]) {
    await assert.rejects(set(ref(host.database,`rooms/abc234/${path}`),value));
  }
  const answers = await Promise.all([play(host,{action:'answer',questionIndex:0,input:'kapi'}),play(guest,{action:'answer',questionIndex:0,input:'kapı'})]);
  assert(answers.every(r=>r.data.committed));
  const h=(await get(ref(host.database,'rooms/abc234'))).val();
  const g=(await get(ref(guest.database,'rooms/abc234'))).val();
  assert.deepEqual(h,g);
  assert.equal(h.race.questionIndex,0);
  assert.equal(h.race.nextAtMs-h.race.resolvedAtMs,2000);
  assert.equal(Object.values(h.progress).filter(p=>p.correctCount===1).length,1);
  assert.deepEqual(Object.values(h.progress).map(p=>p.score).sort((a,b)=>a-b),[0,400]);
  assert.equal(Object.values(h.progress).reduce((s,p)=>s+p.wrongCount,0),0);
  await play(host,{action:'hint',questionIndex:0,expectedRevealedCount:0});
  assert.equal((await db.ref('rooms/abc234/hints').get()).exists(),false);
  // Use an injected server clock to test the exact boundary without sleeping.
  const service=new RaceService({database:db,now:()=>h.race.nextAtMs});
  await Promise.all([service.play(host.uid,{roomId:'abc234',action:'sync'}),service.play(guest.uid,{roomId:'abc234',action:'sync'})]);
  const next=(await db.ref('rooms/abc234').get()).val();
  assert.equal(next.race.questionIndex,1);
  assert.equal(next.race.startedAtMs,h.race.nextAtMs);
  await service.play(guest.uid,{roomId:'abc234',action:'answer',questionIndex:0,input:'kapi'});
  assert.deepEqual((await db.ref('rooms/abc234/progress').get()).val(),h.progress);
});

test('demo start uses server questions and supports dev solo only when explicitly requested', async () => {
  await db.ref().set(null);
  const host=await client('demo-race-host'), guest=await client('demo-race-guest');
  await room('abc234',[host,guest],'quick');
  await db.ref('rooms/abc234/questionEngine').set('demo-v1');
  await assert.rejects(httpsCallable(guest.functions,'startDemoRaceGame')({roomId:'abc234'}),e=>e.code==='functions/permission-denied');
  await httpsCallable(host.functions,'startDemoRaceGame')({roomId:'abc234'});
  const started=(await get(ref(host.database,'rooms/abc234'))).val();
  assert.equal(started.gameplayVersion,'race-v1');assert.equal(started.questions.length,7);
  const demoQuestions=JSON.parse(readFileSync(new URL('../content/demo.json',import.meta.url)));
  await room('def234',[host],'quick');
  await db.ref('rooms/def234').update({questionEngine:'demo-v1',targetPlayerCount:2});
  const prod=new RaceService({database:db,demoQuestions});
  await assert.rejects(prod.startDemo(host.uid,{roomId:'def234',debugSolo:true}),e=>e.code==='failed-precondition');
  await httpsCallable(host.functions,'startDemoRaceGame')({roomId:'def234',debugSolo:true});
  assert.equal((await db.ref('rooms/def234/status').get()).val(),'countdown');
});

test('actual RTDB transactions reserve distinct answers for simultaneous games with overlapping players', async () => {
  await db.ref().set(null);
  const host = clients[0], guest = clients[1];
  const a = await room('abc234',[host,guest]);
  const b = await room('def234',[host,guest]);
  // Two services capture fresh, validated histories before committing either reservation.
  const service = new QuestionService({database: db, pool, includeExamples:true});
  const allocate = async (id, value) => db.ref('questionAllocations').transaction(state => {
    // Imported pure allocator mirrors the exact callable transaction callback.
    return allocation(state,{sessionId:roomKey({...value,id}),roomId:id,mode:'classic',participantIds:[host.uid,guest.uid],histories:[empty,empty],pool,now:Date.now(),includeExamples:true}).state;
  });
  const {allocate: allocation} = await import('../src/allocation.js');
  const [first,second] = await Promise.all([allocate('abc234',a),allocate('def234',b)]);
  assert(first.committed && second.committed);
  const sessions = Object.values((await db.ref('questionAllocations').get()).val().sessions);
  assert.equal(sessions.length,2);
  assert(!sessions[0].questions.some(q=>sessions[1].questions.some(p=>p.answerId===q.answerId)));
  await db.ref('questionPreparations/expired').set({expiresAtMs:1,seenAnswerIds:['old']});
  await service.cleanup();
  assert.equal((await db.ref('questionPreparations/expired').get()).exists(),false);
});

test('empty production pool reports blocked lengths; no draft or repeat fallback starts the room', async () => {
  await db.ref().set(null);
  const host=clients[0],guest=clients[1];
  await room('abc234',[host,guest]);
  const service = new QuestionService({database:db,pool:[]});
  await service.prepare(host.uid,{roomId:'abc234',history:empty});
  await service.prepare(guest.uid,{roomId:'abc234',history:empty});
  await assert.rejects(service.start(host.uid,{roomId:'abc234'}),e=>e.code==='resource-exhausted'&&e.details.capacity.blockedLengths.length===7);
  assert.equal((await db.ref('rooms/abc234/status').get()).val(),'lobby');
});
test('a room deleted between allocation and commit is not recreated; unshown allocation is released', async () => {
  await db.ref().set(null);
  const host=clients[0],guest=clients[1];
  await room('abc234',[host,guest]);
  const deletingDatabase={ref(path) {
    const reference=db.ref(path);
    if(path==='questionAllocations') {
      const original=reference.transaction.bind(reference);
      reference.transaction=async callback=>{
        const result=await original(callback);
        await db.ref('rooms/abc234').remove();
        return result;
      };
    }
    return reference;
  }};
  const service=new QuestionService({database:deletingDatabase,pool,includeExamples:true});
  await service.prepare(host.uid,{roomId:'abc234',history:empty});
  await service.prepare(guest.uid,{roomId:'abc234',history:empty});
  await assert.rejects(service.start(host.uid,{roomId:'abc234'}),e=>e.code==='aborted');
  assert.equal((await db.ref('rooms/abc234').get()).exists(),false);
  assert.equal(Object.keys((await db.ref('questionAllocations').get()).val()?.sessions??{}).length,0);
});
