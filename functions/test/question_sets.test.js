import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {partitionExistingQuestions,resolveQuestionSets,createQuestionSet,selectPublishedSet,setCapacityReport} from '../src/question_sets.js';
import {allocate,validateHistory} from '../src/allocation.js';

const pool=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));
const manifests=partitionExistingQuestions(pool).sets;
const sets=resolveQuestionSets(manifests,pool);
test('migration preserves all fourteen imported sets and admits only complete reviewed sets',()=>{
 assert.equal(sets.length,24);
 for(let i=1;i<=14;i++)assert(manifests[`initial_${String(i).padStart(3,'0')}`]);
 assert.equal(new Set(sets.flatMap(s=>s.questionIds)).size,336);
 for(const set of sets)assert.equal(set.questions.length,14);
 assert.throws(()=>createQuestionSet('partial',sets[0].questions.slice(0,13)));
 assert.throws(()=>resolveQuestionSets({bad:{...sets[0],questionIds:sets[0].questionIds.slice(0,13)}},pool));
 assert.throws(()=>resolveQuestionSets({bad:{...sets[0],fingerprint:'forged'}},pool));
 assert.throws(()=>resolveQuestionSets(manifests,pool.slice(1)));
});
test('a completed set of any participant is excluded without mixing the remaining set',()=>{
 const history=validateHistory({seenAnswerIds:[],seenQuestionIds:[],completedSetIds:[sets[0].id,sets[0].id]});
 assert.equal(history.completedSetIds.length,1);
 const selected=selectPublishedSet(sets.slice(0,2),[{},history],{random:()=>0});
 assert.equal(selected.id,sets[1].id);
 assert.deepEqual(selected.questionIds,sets[1].questionIds);
 assert.equal(setCapacityReport(sets.slice(0,2),[history]).upperBoundSets,1);
 assert.throws(()=>selectPublishedSet(sets.slice(0,1),[history]),e=>e.code==='sets-exhausted');
 assert.throws(()=>validateHistory({seenAnswerIds:[],seenQuestionIds:[],completedSetIds:['../forged']}));
});
test('new allocations keep a stable content identity, and an abandoned set remains replayable',()=>{
 const options={roomId:'abc234',mode:'classic',participantIds:['host'],histories:[{}],sets:sets.slice(0,1),pool,now:1000};
 const first=allocate(null,{...options,sessionId:'first'});
 const replay=allocate(first.state,{...options,roomId:'def234',sessionId:'second',now:2000});
 assert.equal(replay.session.contentSetId,first.session.contentSetId);
 assert.deepEqual(replay.session.questions,first.session.questions);
 assert.throws(()=>allocate(null,{...options,sessionId:'finished',histories:[{completedSetIds:[first.session.contentSetId]}]}),e=>e.code==='sets-exhausted');
});

test('a pending start from a stopped process cannot reuse a set now completed by a participant',()=>{
 const options={roomId:'abc234',sessionId:'pending',mode:'classic',participantIds:['host','guest'],histories:[{},{}],sets:sets.slice(0,1),now:1000};
 const first=allocate(null,options);
 const resumed=allocate(first.state,{...options,sets:sets.slice(0,2),histories:[{},{completedSetIds:[first.session.contentSetId]}],now:2000});
 assert.equal(resumed.session.contentSetId,sets[1].id);
});
