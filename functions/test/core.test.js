import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {answerId, approveQuestion, candidatePrompt, fingerprint, isPublished, normalizeWord, REVIEW_CHECKS, validatePool, validateQuestion} from '../src/content.js';
import {capacityReport, PoolError, selectSet} from '../src/set_selector.js';
import {allocate, release, validateHistory} from '../src/allocation.js';

const pool = JSON.parse(readFileSync(new URL('../content/examples.json', import.meta.url)));
const options = {includeExamples: true};
const checks = Object.fromEntries(REVIEW_CHECKS.map(k => [k, true]));
const reviewed = q => ({...approveQuestion({...q, review: {status: 'draft'}, publication: 'unpublished'}, 'test-editor', checks, 1), publication: 'published'});
const history = questions => ({seenAnswerIds: questions.map(q => q.answerId), seenQuestionIds: questions.map(q => q.id)});

test('Turkish canonical identity handles I/ı, İ/i and NFC; ASCII tolerance does not merge identities', () => {
  assert.equal(normalizeWord('  ılık '), 'ILIK');
  assert.equal(normalizeWord('inci'), 'İNCİ');
  assert.equal(answerId('kİtap'), answerId('kitap'));
  assert.equal(answerId('o\u0308rdek'), answerId('ördek'));
  assert.equal(answerId('I\u0307NCİ'), answerId('inci'));
  assert.equal(answerId('i\u0307nci'), answerId('inci'));
  assert.notEqual(answerId('sıkı'), answerId('siki'));
});
test('editor approval is required and stale approval cannot publish a changed clue', () => {
  const q = pool[0];
  assert(isPublished(q, options));
  assert(!isPublished(q));
  assert(!isPublished({...q, clue: 'Changed clue'}, options));
  assert.throws(() => approveQuestion(q, 'editor', {...checks, uniqueAnswer: false}));
  assert(validateQuestion({...q, publication: 'published', review: {status: 'draft'}}).includes('unreviewed-publication'));
  assert.throws(() => reviewed({...q, source: {...q.source, rights: 'unknown'}}), /source-rights-not-cleared/);
});
test('source rights, single word, letter count, answer/root leaks and duplicate clue checks', () => {
  assert.equal(validatePool(pool).length, 0);
  assert(validateQuestion({...pool[0], answer: 'İKİ KELİME'}).includes('not-a-single-turkish-word'));
  assert(validateQuestion({...pool[0], letterCount: 5}).includes('invalid-length'));
  assert(validateQuestion({...pool[0], clue: 'Kapıyı açmak için kullanılan geçit.'}).includes('answer-leak'));
  assert(validateQuestion({...pool[0], clue: 'kapi yazılan geçit.'}).includes('answer-leak'));
  assert(validateQuestion({...pool[0], rootText: 'geç', clue: 'Geçidin diğer adı.'}).includes('root-leak'));
  assert(validatePool([pool[0], {...pool[0], id: 'other'}]).some(e => e.errors[0].startsWith('near-duplicate')));
  assert.throws(() => candidatePrompt({...pool[0], source: {...pool[0].source, rights: 'permission-required'}}));
});
test('classic selects fourteen distinct answers, two per length, balanced topics/difficulties', () => {
  const result = selectSet(pool, [], options);
  assert.equal(result.questions.length, 14);
  for (let n = 4; n <= 10; n++) assert.equal(result.questions.filter(q => q.letterCount === n).length, 2);
  assert.equal(new Set(result.questions.map(q => q.answerId)).size, 14);
  assert.equal(new Set(result.questions.map(q => q.topic)).size, 3);
  assert.equal(new Set(result.questions.map(q => q.difficulty)).size, 3);
  assert.equal(result.fingerprint, fingerprint([...result.questions].reverse()));
});
test('quick preserves seven questions and one per length', () => {
  assert.deepEqual(selectSet(pool, [], {...options, mode: 'quick'}).questions.map(q => q.letterCount), [4,5,6,7,8,9,10]);
});
test('all players seen answers and question IDs are excluded, including alternate clues', () => {
  const variant = reviewed({...pool[0], id: 'variant', clue: 'Duvar açıklığını örterken menteşe üzerinde dönen yapı.'});
  const result = selectSet([...pool, variant], [{seenAnswerIds: [pool[0].answerId]}, {seenQuestionIds: [pool[1].id]}], options);
  assert(!result.questions.some(q => [pool[0].answerId, pool[1].answerId].includes(q.answerId)));
  assert.equal(variant.answerId, pool[0].answerId);
});
test('related roots cannot coexist in a set', () => {
  const linked = pool.map(q => reviewed({...q, rootId: q.letterCount < 6 ? 'shared-root' : q.rootId}));
  assert.throws(() => selectSet(linked, [], {...options, searchBudget: 2000}), e => e instanceof PoolError && ['balance-unavailable','selection-budget-exceeded'].includes(e.code));
});
test('exhaustion and balancing failure never loosen novelty or publish drafts', () => {
  const remaining = pool.filter(q => q.letterCount !== 4);
  assert.throws(() => selectSet(remaining, [], options), e => e.code === 'pool-exhausted' && e.report.blockedLengths.includes(4));
  assert.throws(() => selectSet(pool, [], {}), e => e.code === 'pool-exhausted');
  const unbalanced = pool.map(q => reviewed({...q, topic: 'one-topic'}));
  assert.throws(() => selectSet(unbalanced, [], options), e => e.code === 'balance-unavailable');
});
test('capacity counts answers, not variants or set combinations, and reports upper bounds', () => {
  const report = capacityReport([...pool, reviewed({...pool[0], id: 'variant2', clue: 'Bir bina girişindeki açılır kapanır bölüm.'})], [], options);
  assert.equal(report.groups[0].publishedAnswers, 6);
  assert.equal(report.upperBoundSets, 3);
  assert.equal(report.upperBoundDays, 1);
  assert.equal(capacityReport(pool, [history(selectSet(pool, [], options).questions)], options).upperBoundSets, 2);
});
test('allocation is idempotent, reserves across concurrent sessions and releases unshown content', () => {
  const request = {sessionId: 'a', roomId: 'abc234', mode: 'classic', participantIds: ['u'], histories: [], pool, now: 1000, includeExamples: true};
  const first = allocate(null, request);
  const duplicate = allocate(first.state, request);
  assert.deepEqual(duplicate.session, first.session);
  const second = allocate(first.state, {...request, sessionId: 'b'});
  assert(!second.session.questions.some(q => first.session.questions.some(p => p.answerId === q.answerId)));
  assert.deepEqual(allocate(release(second.state, 'a', 1000), {...request, sessionId: 'a'}).session.questions.length, 14);
  assert.equal(Object.keys(allocate(first.state, {...request, sessionId: 'c', now: 999999}).state.sessions).length, 1);
});
test('only shown history is permanent: expired reservations may be reused, seen answers cannot', () => {
  const req = {sessionId: 'a', roomId: 'abc234', mode: 'classic', participantIds: ['u'], histories: [], pool, now: 1000, includeExamples: true};
  const first = allocate(null, req);
  const shown = first.session.questions.slice(0, 1);
  const next = allocate(first.state, {...req, sessionId: 'b', now: 999999, histories: [history(shown)]});
  assert(!next.session.questions.some(q => q.answerId === shown[0].answerId));
});
test('history validates IDs and bounded payloads', () => {
  assert.throws(() => validateHistory({seenAnswerIds: ['../path'], seenQuestionIds: []}));
  assert.deepEqual(validateHistory({seenAnswerIds: ['x','x'], seenQuestionIds: []}).seenAnswerIds, ['x']);
});
test('a delayed room commit retries the same questions with a fresh clock', () => {
  const request = {sessionId:'a',roomId:'abc234',mode:'classic',participantIds:['u'],histories:[],pool,now:1000,includeExamples:true};
  const first=allocate(null,request);
  const retry=allocate(first.state,{...request,now:50000});
  assert.deepEqual(first.session.questions,retry.session.questions);
  assert.equal(first.session.startsAtMs,5000);
  assert.equal(retry.session.startsAtMs,54000);
});
