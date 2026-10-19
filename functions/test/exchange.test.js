import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {prepareExchange} from '../tools/prepare_exchange.js';
import {answerId, isPublished, validateQuestion, validatePool} from '../src/content.js';
import {allocate} from '../src/allocation.js';

const batch = JSON.parse(readFileSync(new URL('../../content/sets/luna_sets_005_014_20261015.exchange.json', import.meta.url)));
// Historical exchange inputs used one hint; exercise the current import contract.
const reviewedHints=new Map(JSON.parse(readFileSync(new URL('../../content/sets/question_hints_20261018.reviewed.json',import.meta.url))).questions.map(q=>[q.answer,q.hints]));
for(const set of batch.sets)for(const q of set.questions)q.hints=reviewedHints.get(q.answer);
const batchIds = new Set(batch.sets.flatMap(set => set.questions.map(q => q.id)));
const original = JSON.parse(readFileSync(new URL('../content/published.json', import.meta.url)))
  .filter(q => !batchIds.has(q.id));
const prepared = prepareExchange(batch, original, 1);

test('corrected batch produces 140 reviewed records and additive RTDB JSON strings without touching the existing pool', () => {
  assert.equal(prepared.questions.length, 140);
  assert.equal(prepared.summary.combinedPoolQuestions, original.length + 140);
  assert.equal(prepared.summary.acceptedAlternatives, 17);
  assert.deepEqual(validatePool(prepared.questions), []);
  assert(prepared.questions.every(q => q.publication === 'unpublished'));
  assert.equal(Object.keys(prepared.publicationUpdates).filter(k=>k.startsWith('questionPool/setIndex/')).length,10);
  assert.equal(Object.keys(prepared.publicationUpdates).filter(k=>k.startsWith('questionPool/sets/')).length,10);
  for (const [id, json] of Object.entries(prepared.rtdb)) {
    const q = JSON.parse(json);
    assert.equal(q.id, id); assert(isPublished(q));
  }
});

test('spaced answers retain spelling and identity, while layout counts letters only', () => {
  const q = prepared.questions.find(q => q.answer === 'NEFES ALMAK');
  assert.equal(q.letterCount, 10); assert.deepEqual(q.wordLengths, [5, 5]);
  assert.deepEqual(q.acceptedAnswers, ['SOLUK ALMAK']);
  assert.notEqual(q.answerId, answerId('NEFESALMAK'));
  assert(validateQuestion({...q, wordLengths: [10]}).includes('invalid-word-lengths'));
  assert(validateQuestion({...q, acceptedAnswers: ['VAAT ETMEK']}).includes('invalid-accepted-answers'));
  assert(validateQuestion({...q, acceptedAnswers: ['soluk almak']}).includes('invalid-accepted-answers'));
});

test('changed hints or alternatives invalidate approval, and direct hint leaks are rejected', () => {
  const q = prepared.questions.find(q => q.answer === 'YAZI');
  assert(validateQuestion({...q, hint: 'Madeni parada yazı yüzü.'}).includes('hint-answer-leak'));
  assert(validateQuestion({...q, hint: 'Different fact.'}).includes('invalid-editor-approval'));
  assert(validateQuestion({...q, acceptedAnswers: ['HARF']}).includes('invalid-editor-approval'));
  assert(validateQuestion({...q, hints: ['İki kelime.', q.hints[1]]}).includes('bare-structural-hint'));
  assert(validateQuestion({...q, hints: [q.hints[0]]}).includes('invalid-hints'));
  assert(validateQuestion({...q, hints: [q.hints[0], q.hints[0]]}).includes('invalid-hints'));
});

test('incomplete source/editor evidence and duplicates cannot become upload artifacts', () => {
  const unverified = structuredClone(batch);
  unverified.sets[0].questions[0].source.verificationStatus = 'needs_recheck';
  assert.throws(() => prepareExchange(unverified), /checks incomplete/);
  const unreviewed = structuredClone(batch);
  unreviewed.sets[0].questions[0].review.checks.hintNoLeak = false;
  assert.throws(() => prepareExchange(unreviewed), /checks incomplete/);
  assert.throws(() => prepareExchange(batch, prepared.questions), /Duplicate/);
});

test('allocated room questions carry accepted alternatives without exposing editorial/source records', () => {
  const set = prepared.questions.filter(q => q.generation.setId === 'initial_007')
    .map(q => ({...q, publication: 'published'}));
  const {session} = allocate(null, {sessionId:'test', roomId:'abc234', mode:'classic', participantIds:['u'], histories:[], pool:set, now:1});
  const q = session.questions.find(q => q.answer === 'NEFES ALMAK');
  assert.deepEqual(q.acceptedAnswers, ['SOLUK ALMAK']);
  assert.equal(q.letterCount, 10); assert.equal(q.source, undefined);
  assert.deepEqual(q.hints, set.find(question=>question.id===q.id).hints);
  assert.equal(q.review, undefined);
});
