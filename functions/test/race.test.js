import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {reduceRace, RaceService, initialRace, QUESTION_MS, REVEAL_MS} from '../src/race.js';

const demo = JSON.parse(readFileSync(new URL('../content/demo.json', import.meta.url)));
const room = () => ({status:'playing', gameplayVersion:'race-v1', targetPlayerCount:2,
  players:{arman:{displayName:'Arman'}, yalin:{displayName:'Yalın'}},
  questions:demo.filter((_, i) => i % 2 === 0), race:initialRace(1000)});
const answer = (index, input) => ({action:'answer', questionIndex:index, input});

test('first correct wins once; stale answers/hints cannot score or change the reveal deadline', () => {
  const original = room();
  const won = reduceRace(original, 'arman', answer(0, 'kapi'), 1200);
  assert.equal(original.race.winnerId, undefined); // No callback mutation across retries.
  assert.equal(won.race.winnerId, 'arman');
  assert.equal(won.race.winnerName, 'Arman');
  assert.equal(won.race.nextAtMs, 3200);
  assert.equal(won.progress.arman.score, 400);
  assert.equal(won.progress.yalin.score, 0);
  assert.equal(won.progress.yalin.wrongCount, 0);
  assert.equal(won.progress.yalin.skippedCount, 1);
  assert.deepEqual(reduceRace(won, 'yalin', answer(0, 'kapı'), 1201), won);
  assert.deepEqual(reduceRace(won, 'yalin', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1300), won);
  const next = reduceRace(won, 'yalin', answer(0, 'kapi'), 3200);
  assert.equal(next.race.questionIndex, 1);
  assert.equal(next.race.startedAtMs, 3200);
  assert.equal(next.progress.yalin.score, 0);
  assert.equal(next.progress.arman.correctCount, 1);
});

test('wrong answer costs no points and cannot claim a winner later', () => {
  let r = reduceRace(room(), 'yalin', answer(0, 'saat'), 1100);
  r = reduceRace(r, 'arman', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1200);
  assert.equal(r.hints[0].revealedCount, 1);
  assert.equal(r.progress.yalin.lastScoreDelta, 0);
  r = reduceRace(r, 'yalin', answer(0, 'kapi'), 1250);
  assert.equal(r.race.winnerId, undefined);
  r = reduceRace(r, 'arman', answer(0, 'kapi'), 1300);
  assert.equal(r.progress.arman.score, 300);
  assert.equal(r.progress.yalin.score, 0);
  assert.equal(r.progress.yalin.wrongCount, 1);
  assert.equal(r.progress.yalin.skippedCount, 0);
});

test('last incorrect answer immediately reveals for everyone without changing earned scores', () => {
  let r = room();
  r.targetPlayerCount = 3;
  r.players.ayse = {displayName:'Ayşe'};
  r.progress = {arman:{score:400}, yalin:{score:700}, ayse:{score:100}};
  r = reduceRace(r, 'arman', answer(0, 'saat'), 1100);
  assert.equal(r.race.nextAtMs, undefined);
  r = reduceRace(r, 'yalin', answer(0, ''), 1200);
  assert.equal(r.race.nextAtMs, undefined); // One remaining player still has a chance.
  const before = structuredClone(r);
  r = reduceRace(r, 'ayse', answer(0, 'aaaa'), 1300);
  assert.equal(before.race.nextAtMs, undefined); // RTDB callback input is immutable.
  assert.equal(r.race.reason, 'all-wrong');
  assert.equal(r.race.resolvedAtMs, 1300);
  assert.equal(r.race.nextAtMs, 1300 + REVEAL_MS);
  assert.equal(r.race.winnerId, undefined);
  assert.deepEqual(Object.values(r.progress).map(p => p.score), [400,700,100]);
  for (const progress of Object.values(r.progress)) {
    assert.equal(progress.wrongCount, 1);
    assert.equal(progress.lastOutcome, 'wrong');
    assert.equal(progress.lastScoreDelta, 0);
  }
  assert.deepEqual(reduceRace(r, 'arman', answer(0, 'kapi'), 1400), r);
  assert.deepEqual(reduceRace(r, 'ayse', answer(0, ''), 1401), r);
  assert.equal(reduceRace(r, 'yalin', {action:'sync'}, 1300 + REVEAL_MS - 1).race.questionIndex, 0);
  const next = reduceRace(r, 'yalin', {action:'sync'}, 1300 + REVEAL_MS);
  assert.equal(next.race.questionIndex, 1);
  assert.equal(next.race.startedAtMs, 1300 + REVEAL_MS);
  assert.equal(next.race.nextAtMs, undefined);
  assert.deepEqual(Object.values(next.progress).map(p => p.wrongCount), [1,1,1]);
});

test('offline players keep their chance; a departed player no longer delays the remaining attempts', () => {
  let r = room();
  r.players.arman.isOnline = false;
  r = reduceRace(r, 'yalin', answer(0, ''), 1100);
  assert.equal(reduceRace(r, 'yalin', {action:'sync'}, 1200).race.nextAtMs, undefined);
  delete r.players.arman;
  const resolved = reduceRace(r, 'yalin', {action:'sync'}, 1300);
  assert.equal(resolved.race.reason, 'all-wrong');
  assert.equal(resolved.race.resolvedAtMs, 1300);
  assert.equal(resolved.race.nextAtMs, 1300 + REVEAL_MS);
});

test('sync resolves already exhausted rounds and retries do not move the reveal deadline', () => {
  const r = room();
  r.progress = {arman:{questionIndex:1,score:0,wrongCount:1,lastOutcome:'wrong'},
    yalin:{questionIndex:1,score:0,wrongCount:1,lastOutcome:'wrong'}};
  const resolved = reduceRace(r, 'arman', {action:'sync'}, 1400);
  assert.equal(resolved.race.reason, 'all-wrong');
  assert.equal(resolved.race.nextAtMs, 1400 + REVEAL_MS);
  assert.deepEqual(reduceRace(resolved, 'yalin', {action:'sync'}, 1500), resolved);
});

test('all incorrect on the last question reveals then ends without waiting for its deadline', () => {
  let r = room();
  r.race.questionIndex = r.questions.length - 1;
  r = reduceRace(r, 'arman', answer(r.race.questionIndex, ''), 1100);
  r = reduceRace(r, 'yalin', answer(r.race.questionIndex, ''), 1200);
  assert.equal(r.race.reason, 'all-wrong');
  assert.equal(r.status, 'playing');
  for (const progress of Object.values(r.progress)) {
    assert.equal(progress.finished, true);
    assert.equal(progress.wrongCount, 1);
    assert.equal(progress.score, 0);
  }
  const finished = reduceRace(r, 'arman', {action:'sync'}, 1200 + REVEAL_MS);
  assert.equal(finished.status, 'results');
  assert.equal(finished.race.questionIndex, r.questions.length);
});

test('server deadline rejects late answers, reveals for two seconds and catches up offline rooms', () => {
  const expired = reduceRace(room(), 'arman', answer(0, 'kapi'), 26000);
  assert.equal(expired.race.reason, 'timeout');
  assert.equal(expired.race.winnerId, undefined);
  assert.equal(expired.progress.arman.score, 0);
  assert.equal(expired.progress.yalin.score, 0);
  assert.equal(expired.race.questionIndex, 0);
  assert.equal(reduceRace(expired, 'yalin', {action:'sync'}, 27999).race.questionIndex, 0);
  const next = reduceRace(expired, 'yalin', {action:'sync'}, 28000);
  assert.equal(next.race.questionIndex, 1);
  assert.equal(next.race.startedAtMs, 28000);
  const finished = reduceRace(next, 'yalin', {action:'sync'}, 1000 + 7 * (QUESTION_MS + REVEAL_MS));
  assert.equal(finished.status, 'results');
  assert.equal(finished.progress.arman.score, 0);
  assert.equal(finished.progress.yalin.wrongCount, 7);
  assert(finished.progress.yalin.finished);
});

test('three players keep earned points after incorrect speech and timeouts; only the winner gains', () => {
  let r = room();
  r.targetPlayerCount = 3;
  r.players.ayse = {displayName: 'Ayşe'};
  r = reduceRace(r, 'yalin', answer(0, ''), 1100);
  assert.equal(r.progress.yalin.lastOutcome, 'wrong');
  assert.equal(r.progress.yalin.lastScoreDelta, 0);
  assert.equal(r.race.winnerId, undefined);
  r = reduceRace(r, 'arman', answer(0, 'kapi'), 1200);
  assert.deepEqual(Object.values(r.progress).map(p => p.score).sort((a,b) => a-b), [0,0,400]);
  r = reduceRace(r, 'arman', {action:'sync'}, 3200);
  r = reduceRace(r, 'yalin', answer(1, r.questions[1].answer), 3300);
  assert.equal(r.progress.yalin.score, 500);
  assert.equal(r.progress.arman.score, 400);
  r = reduceRace(r, 'ayse', {action:'sync'}, 5300 + QUESTION_MS);
  assert.equal(r.progress.arman.score, 400);
  assert.equal(r.progress.yalin.score, 500);
  assert.equal(r.progress.ayse.score, 0);
  for (const progress of Object.values(r.progress)) assert.equal(progress.lastScoreDelta, 0);
});

test('removed give-up action is rejected', async () => {
  const service = new RaceService({database: {}});
  await assert.rejects(
    service.play('yalin', {roomId:'abc234', action:'giveUp', questionIndex:0}),
    error => error.code === 'invalid-argument',
  );
});

test('final winner immediately closes scoring; results follow the reveal, independent of the old total clock', () => {
  let r = room();
  let at = 1000;
  for (let index = 0; index < 7; index++) {
    r = reduceRace(r, 'arman', answer(index, r.questions[index].answer), at);
    assert.equal(r.status, 'playing');
    assert.equal(r.progress.yalin.score, 0);
    at += REVEAL_MS;
    r = reduceRace(r, 'yalin', {action:'sync'}, at);
  }
  assert.equal(r.status, 'results');
  assert.equal(r.progress.arman.score, 4900);
  assert.equal(r.progress.yalin.skippedCount, 7);
  assert.equal(r.progress.yalin.wrongCount, 0);
  assert.deepEqual(reduceRace(r, 'arman', answer(6, 'merdiven'), at), r);
});

test('Turkish ASCII, spaces and approved synonyms work on the server; countdown and membership gate actions', () => {
  let r = room();
  r.questions[0] = {answer:'NEFES ALMAK',acceptedAnswers:['SOLUK ALMAK']};
  const won = reduceRace(r, 'arman', answer(0, 'solukalmak'), 1000);
  assert.equal(won.race.winnerId, 'arman');
  assert.equal(won.progress.arman.score, 1000);
  assert.deepEqual(reduceRace(r, 'arman', answer(0, 'solukalmak'), 999), r);
  assert.throws(() => reduceRace(r, 'outsider', answer(0, 'solukalmak'), 1000), e => e.code === 'permission-denied');
  assert.throws(() => reduceRace(r, 'arman', answer(0, 'a'), 1000), e => e.code === 'invalid-argument');
  const dart = readFileSync(new URL('../../lib/features/game/data/question_bank.dart', import.meta.url), 'utf8');
  const pairs = [...dart.matchAll(/clue: '([^']*)',\s+answer: '([^']*)'/gu)].map(m => ({clue:m[1],answer:m[2],letterCount:m[2].length}));
  assert.deepEqual(demo.map(({hints,...q})=>q), pairs, 'Demo server/client questions must stay identical.');
  for(const q of demo){assert.equal(q.hints.length,2);for(const h of q.hints)assert(dart.includes(h));}
});

test('four-player votes require two distinct players and winning locks further votes', () => {
  const base = room(); base.targetPlayerCount = 4;
  base.players.ayse = {displayName:'Ayşe'}; base.players.ali = {displayName:'Ali'};
  const a = reduceRace(base, 'arman', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1001);
  assert.equal(a.hints[0].revealedCount, 0);
  assert.equal(a.hints[0].firstVoterId, 'arman');
  assert.deepEqual(reduceRace(a, 'arman', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1002), a);
  const b = reduceRace(a, 'yalin', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1003);
  assert.deepEqual(b.hints[0], {questionIndex:0,revealedCount:1});
  assert.deepEqual(reduceRace(b, 'arman', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1004), b);
  const twoPlayer = reduceRace(room(), 'arman', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1001);
  assert.deepEqual(reduceRace(twoPlayer, 'yalin', {action:'hint',questionIndex:0,expectedRevealedCount:0}, 1002), twoPlayer);
});

test('personal clues cost one right each, preserve score/letters and retry without double spending', () => {
 const original=room();
 let r=reduceRace(original,'arman',{action:'clueHint',questionIndex:0,expectedHintCount:0},1100);
 assert.equal(r.clueHintUsage.arman[0],1);
 assert.equal(original.clueHintUsage,undefined);
 assert.equal(r.hints,undefined);assert.equal(r.progress,undefined);
 assert.deepEqual(reduceRace(r,'arman',{action:'clueHint',questionIndex:0,expectedHintCount:0},1150),r);
 r=reduceRace(r,'arman',{action:'clueHint',questionIndex:0,expectedHintCount:1},1200);
 assert.equal(r.clueHintUsage.arman[0],2);
 assert.deepEqual(reduceRace(r,'arman',{action:'clueHint',questionIndex:0,expectedHintCount:2},1250),r);
 const guest=reduceRace(r,'yalin',{action:'clueHint',questionIndex:0,expectedHintCount:0},1300);
 assert.equal(guest.clueHintUsage.yalin[0],1);assert.equal(guest.clueHintUsage.arman[0],2);
});

test('ten-right limit survives reconnect and spans questions; late or resolved requests spend nothing', () => {
 let r=room(),at=1000;
 for(let index=0;index<5;index++) {
  r=reduceRace(r,'arman',{action:'clueHint',questionIndex:index,expectedHintCount:0},at);
  r=reduceRace(r,'arman',{action:'clueHint',questionIndex:index,expectedHintCount:1},at+1);
  r=reduceRace(r,'yalin',answer(index,r.questions[index].answer),at+2);
  at+=REVEAL_MS+2;r=reduceRace(r,'arman',{action:'sync'},at);
 }
 r=JSON.parse(JSON.stringify(r));
 assert.equal(Object.values(r.clueHintUsage.arman).reduce((a,b)=>a+b,0),10);
 assert.deepEqual(reduceRace(r,'arman',{action:'clueHint',questionIndex:5,expectedHintCount:0},at+1),r);
 const other=reduceRace(r,'yalin',{action:'clueHint',questionIndex:5,expectedHintCount:0},at+1);
 assert.equal(other.clueHintUsage.yalin[5],1);
 const expired=reduceRace(room(),'arman',{action:'clueHint',questionIndex:0,expectedHintCount:0},26000);
 assert.equal(expired.clueHintUsage,undefined);
 const wrong=reduceRace(room(),'arman',answer(0,'aaaa'),1100);
 assert.deepEqual(reduceRace(wrong,'arman',{action:'clueHint',questionIndex:0,expectedHintCount:0},1200),wrong);
 const absent=room();delete absent.questions[0].hints;
 assert.deepEqual(reduceRace(absent,'arman',{action:'clueHint',questionIndex:0,expectedHintCount:0},1100),absent);
});

test('hint quorum follows the real player count, not the room capacity',()=>{
 const base=room();base.targetPlayerCount=6;
 const hinted=reduceRace(base,'arman',{action:'hint',questionIndex:0,expectedRevealedCount:0},1100);
 assert.equal(hinted.hints[0].revealedCount,1);
});

test('demo starts accept partially filled rooms and permit single-player only for explicit dev debug',async()=>{
 for(const count of [1,2,3])for(const debugSolo of [false,true])for(const allowDebugSolo of [false,true]) {
  let current={...room(),hostId:'arman',status:'lobby',gameMode:'classic',targetPlayerCount:6};
  delete current.gameplayVersion;delete current.race;
  if(count===1)delete current.players.yalin;
  if(count===3)current.players.ayse={displayName:'Ayşe'};
  for(const player of Object.values(current.players))Object.assign(player,{isReady:true,isOnline:true});
  const database={ref:()=>({on:(_,notify)=>notify(),off:()=>{},transaction:async update=>{
   const next=update(current);if(next===undefined)return {committed:false};current=next;return {committed:true};
  }})};
  const service=new RaceService({database,demoQuestions:demo,now:()=>1000,allowDebugSolo});
  if(count===1&&!(debugSolo&&allowDebugSolo)) {
   await assert.rejects(service.startDemo('arman',{roomId:'abc234',debugSolo}),e=>e.code==='failed-precondition');
   assert.equal(current.status,'lobby');
  }else{
   await service.startDemo('arman',{roomId:'abc234',debugSolo});
   assert.equal(current.status,'countdown');assert.equal(current.targetPlayerCount,6);
  }
 }
});
