import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {QuestionService} from '../src/question_service.js';
import {loadPublishedSetIds,loadPublishedSet} from '../src/published_pool.js';
import {partitionExistingQuestions,resolveQuestionSets,selectSetId} from '../src/question_sets.js';

const pool=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));
const manifests=partitionExistingQuestions(pool).sets;
const selected=resolveQuestionSets(manifests,pool)[0];
const history=completedSetIds=>({completedSetIds,seenQuestionIds:[selected.questions[0].id],seenAnswerIds:[selected.questions[0].answerId]});

class MemoryDatabase {
  constructor(data){this.data=structuredClone(data);this.reads=[];}
  value(path){return path.split('/').filter(Boolean).reduce((o,k)=>o?.[k],this.data)??null;}
  put(path,value){const parts=path.split('/'),last=parts.pop();let obj=this.data;for(const p of parts)obj=obj[p]??={};if(value===null)delete obj[last];else obj[last]=structuredClone(value);}
  ref(path) {
    return {get:async()=>{this.reads.push(path);return {val:()=>structuredClone(this.value(path))};},
      set:async value=>this.put(path,value),on:(_,callback)=>{this.reads.push(path);callback();},off:()=>{},
      transaction:async update=>{const next=update(structuredClone(this.value(path)));if(next===undefined)return {committed:false};this.put(path,next);return {committed:true,snapshot:{val:()=>structuredClone(next)}};}};
  }
}

function setup(count=2000) {
  const ids=[selected.id,...Array.from({length:count-1},(_,i)=>`other_${i}`)];
  const players=Object.fromEntries(Array.from({length:5},(_,i)=>[`user${i}`,{isReady:true,isOnline:true,displayName:`Player ${i}`} ]));
  const database=new MemoryDatabase({rooms:{abc234:{hostId:'user0',createdAt:1000,gameMode:'classic',
    questionEngine:'pool-v1',status:'lobby',targetPlayerCount:5,players}},questionPool:{
    setIndex:Object.fromEntries(ids.map(id=>[id,true])),sets:{[selected.id]:manifests[selected.id]},
    published:Object.fromEntries(selected.questions.map(q=>[q.id,JSON.stringify(q)]))}});
  let now=10000;
  const options={database,now:()=>now,loadSetIds:()=>loadPublishedSetIds(database),loadSet:id=>loadPublishedSet(database,id)};
  const service=new QuestionService(options);
  const prepare=async()=>{
    for(let i=0;i<5;i++) {
      // Different devices contribute different exclusions; old answer/question IDs are ignored.
      await service.prepare(`user${i}`,{roomId:'abc234',history:history(ids.slice(1).filter((_,n)=>n%5===i))});
      now+=60000;
    }
  };
  return {database,service,options,ids,prepare,advance:ms=>now+=ms};
}

test('2,000-set index: five staggered devices exclude their union; only selected fourteen questions are read',async()=>{
  const {database,service,prepare}=setup();
  await prepare();
  assert(!database.reads.some(path=>path.startsWith('questionPool/published')||path.startsWith('questionPool/sets')));
  for(let i=0;i<5;i++) {
    const prepared=database.value(`questionPreparations/user${i}`);
    assert.equal(prepared.seenAnswerIds,undefined);assert.equal(prepared.seenQuestionIds,undefined);
  }
  await service.start('user0',{roomId:'abc234'});
  const started=database.value('rooms/abc234');
  assert.equal(started.contentSetId,selected.id);assert.equal(started.status,'countdown');
  assert.deepEqual(started.questions.map(q=>q.id),selected.questionIds);
  assert(started.questions.every(q=>q.hints.length===2&&!q.source&&!q.review));
  assert.equal(database.reads.filter(path=>path.startsWith('questionPool/sets/')).length,1);
  assert.equal(database.reads.filter(path=>path.startsWith('questionPool/published/')).length,14);
  assert(!database.reads.includes('questionPool'));assert(!database.reads.includes('questionPool/published'));
  assert(!database.reads.includes('questionAllocations'),'Allocation reads only this room, not every active game.');
  const reads=database.reads.length;
  await service.start('user0',{roomId:'abc234'});
  assert.equal(database.reads.length,reads+1,'Started room retries never reload content.');
});

test('a set finished by even the fifth player cannot be fetched; exhaustion leaves lobby intact',async()=>{
  const {database,service,prepare}=setup(1);
  await prepare();
  await service.prepare('user4',{roomId:'abc234',history:history([selected.id])});
  await assert.rejects(service.start('user0',{roomId:'abc234'}),error=>error.code==='resource-exhausted'&&error.details.capacity.upperBoundSets===0);
  assert.equal(database.value('rooms/abc234/status'),'lobby');
  assert(!database.reads.some(path=>path.startsWith('questionPool/sets/')));
});

test('missing, expired or different-room histories never start a five-player room',async()=>{
  for(const change of [s=>s.database.put('questionPreparations/user4',null),
    s=>s.advance(60*60*1000),s=>s.database.put('questionPreparations/user4/roomKey','other-room')]) {
    const state=setup(1);await state.prepare();change(state);
    await assert.rejects(state.service.start('user0',{roomId:'abc234'}),error=>error.code==='failed-precondition');
    assert.equal(state.database.value('rooms/abc234/status'),'lobby');
    assert(!state.database.reads.some(path=>path.startsWith('questionPool/sets/')));
  }
});

test('membership changes during selected-set fetch abort the commit and release its allocation',async()=>{
  const {database,options,prepare}=setup(1);await prepare();
  const service=new QuestionService({...options,loadSet:async id=>{
    const result=await options.loadSet(id);database.put('rooms/abc234/players/user4',null);return result;
  }});
  await assert.rejects(service.start('user0',{roomId:'abc234'}),error=>error.code==='aborted');
  assert.equal(database.value('rooms/abc234/status'),'lobby');
  assert.equal(Object.keys(database.value('questionAllocations/sessions')??{}).length,0);
});

test('selected set integrity still rejects missing questions, forged fingerprints and unsafe IDs',async()=>{
  for(const change of [db=>db.put(`questionPool/published/${selected.questionIds[0]}`,null),
    db=>db.put(`questionPool/sets/${selected.id}/fingerprint`,'forged'),
    db=>db.put(`questionPool/sets/${selected.id}/questionIds`,['../unsafe',...selected.questionIds.slice(1)])]) {
    const {database}=setup(1);change(database);
    await assert.rejects(loadPublishedSet(database,selected.id));
  }
  await assert.rejects(loadPublishedSet(setup(1).database,'../unsafe'));
  const {database}=setup(1);database.put('questionPool/setIndex/bad',false);
  await assert.rejects(loadPublishedSetIds(database));
});

test('selection ignores words and answers, and unfinished sets stay replayable',()=>{
  assert.equal(selectSetId([selected.id],[history([])]),selected.id);
  assert.throws(()=>selectSetId([selected.id],[history([selected.id])]),error=>error.code==='sets-exhausted');
});
