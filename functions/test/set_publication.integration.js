import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {CloudQuestionGenerator} from '../src/cloud_generation.js';
import {loadPublishedSets} from '../src/published_pool.js';
import {selectSet} from '../src/set_selector.js';
import {GENERATION_LIMITS} from '../src/generation_policy.js';
import {QuestionService} from '../src/question_service.js';

if(process.env.GCLOUD_PROJECT!=='demo-kelime-yarisi'||!process.env.FIREBASE_DATABASE_EMULATOR_HOST?.startsWith('127.0.0.1:'))throw new Error('Local demo RTDB emulator only.');
const app=initializeApp({projectId:'demo-kelime-yarisi',databaseURL:'https://demo-kelime-yarisi-default-rtdb.firebaseio.com'});
const db=getDatabase(app);
after(async()=>{db.goOffline();await deleteApp(app);});
const pool=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));
test('real RTDB serialization preserves ten drafts across days; only the complete set becomes playable',async()=>{
 await db.ref().set({questionGeneration:{control:{enabled:true,projectId:'demo-kelime-yarisi'}}});
 const {questions}=selectSet(pool,[],{random:()=>0.5});
 let calls=0;
 const settings={database:db,projectId:'demo-kelime-yarisi',bundledPool:[],sources:questions,apiKey:'mock-test-key',
  now:()=>Date.parse('2026-10-18T08:00:00Z'),limits:{...GENERATION_LIMITS,attempts:10},
  generate:async source=>{calls++;return {...source,publication:'unpublished'};}};
 const first=await new CloudQuestionGenerator(settings).run();
 assert.equal(first.draftQuestions,10);assert.equal(first.setsPublishedToday,0);
 assert.equal((await loadPublishedSets(db,[])).length,0);
 assert.equal((await db.ref('questionPool/published').get()).exists(),false);
 const next=await new CloudQuestionGenerator({...settings,now:()=>Date.parse('2026-10-19T08:00:00Z'),limits:GENERATION_LIMITS}).run();
 assert.equal(next.setsPublishedToday,1);assert.equal(calls,14);
 const [set]=await loadPublishedSets(db,[]);assert.equal(set.questions.length,14);
 assert.equal((await db.ref('questionGeneration/draft').get()).exists(),false);
 const roomId='abc234';const now=Date.now();
 const room=()=>({name:'Set integration',code:'ABC-234',hostId:'host',targetPlayerCount:2,playerCount:1,
  gameMode:'classic',status:'lobby',createdAt:now,questionEngine:'pool-v1',
  players:{host:{displayName:'Tester',isHost:true,isReady:false,isOnline:true,lastSeenAt:now}}});
 await db.ref(`rooms/${roomId}`).set(room());
 const service=new QuestionService({database:db,pool:[],allowDebugSolo:true,loadSets:()=>loadPublishedSets(db,[])});
 const empty={seenAnswerIds:[],seenQuestionIds:[],completedSetIds:[]};
 await service.prepare('host',{roomId,history:empty});
 await service.start('host',{roomId,debugSolo:true});
 const started=(await db.ref(`rooms/${roomId}`).get()).val();
 assert.equal(started.contentSetId,set.id);assert.equal(started.questions.length,14);
 assert.deepEqual(started.questions.map(q=>q.id),set.questionIds);
 await db.ref('rooms/def234').set({...room(),code:'DEF-234',createdAt:now+1});
 await service.prepare('host',{roomId:'def234',history:{...empty,completedSetIds:[set.id]}});
 await assert.rejects(service.start('host',{roomId:'def234',debugSolo:true}),e=>e.code==='resource-exhausted');
 // Abandoning a room has no completion history and can select that same set again.
 await service.prepare('host',{roomId:'def234',history:empty});
 await service.start('host',{roomId:'def234',debugSolo:true});
 assert.equal((await db.ref('rooms/def234/contentSetId').get()).val(),set.id);
});
