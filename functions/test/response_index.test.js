import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {ResponseIndex, reserveResponses, responseIndexUpdates, RESPONSE_INDEX_PATH} from '../src/response_index.js';
import {answerId, approveQuestion, REVIEW_CHECKS, validatePool} from '../src/content.js';
import {generateQuestion, replenishmentPlan} from '../src/content_generation.js';

const published = JSON.parse(readFileSync(new URL('../content/published.json', import.meta.url)));
const checks = Object.fromEntries([...REVIEW_CHECKS, 'hintConsistency', 'hintNoLeak'].map(check => [check, true]));
function question(answer, id, clue, acceptedAnswers = []) {
  const q = {...published[0], answer, id, answerId: answerId(answer), rootId: answerId(answer), rootText: answer,
    letterCount: answer.length, wordLengths: [answer.length], answerType: 'word', clue, acceptedAnswers,
    hints: ['Günlük yaşamda karşılaşılır.', 'Farklı bağlamlarda kullanılır.'],
  };
  return approveQuestion(q, 'Unit test fixture', checks, 1);
}
const first = question('SIRA', 'first', 'Peş peşe duran kişilerin oluşturduğu düzen.', ['DİZİ']);
const next = question('İNCİ', 'next', 'Deniz canlısının içinde oluşan değerli küçük tanecik.');

function database(index) {
  const db = {index: structuredClone(index), listeners: 0, latest: null};
  db.ref = path => {
    assert.equal(path, RESPONSE_INDEX_PATH);
    return {
      on(_event, listener) {db.listeners++;queueMicrotask(listener);},
      off() {db.listeners--;},
      async transaction(update) {
        if (db.latest) {update(structuredClone(db.index));db.index = db.latest;}
        const result = update(structuredClone(db.index));
        if (result !== undefined) db.index = result;
        return {committed: result !== undefined, snapshot: {val: () => structuredClone(db.index)}};
      },
    };
  };
  return db;
}

test('index keeps Turkish canonical answers and known synonyms, not source/review/question payloads', () => {
  const index = ResponseIndex.fromQuestions([first, next]);
  assert.equal(index.data.uniqueResponses[answerId('SIRA')], 'SIRA');
  assert.equal(index.data.acceptedResponses[answerId('DİZİ')], 'DİZİ');
  assert(index.hasAnswer(answerId('inci')));
  assert(!index.hasAnswer(answerId('ıncı')));
  assert.equal(index.count(4), 2);
  for (const forbidden of ['meaningEvidence', 'rationale', 'hints', 'source', 'clue"']) {
    assert(!JSON.stringify(index.data).includes(forbidden));
  }
  const rt = new ResponseIndex(JSON.parse(JSON.stringify(index.data)));
  assert.deepEqual(rt.data, index.data);
});

test('both planning and the paid-call boundary reject already indexed target responses', async () => {
  const index = ResponseIndex.fromQuestions([first]);
  const alias = question('DİZİ', 'alias', 'Birbirini izleyen eserlerin bütünü.');
  const plan = replenishmentPlan([first, alias, next], [], {limit: 10, responseIndex: index});
  assert.deepEqual(plan.selected.map(q => q.id), ['next']);
  let requests = 0;
  for (const source of [first, alias]) {
    await assert.rejects(generateQuestion(source, [], {model: 'unit-test', apiKey: 'unit-only-key', responseIndex: index,
      fetchImpl: async () => {requests++;throw new Error('must not call');}}), /already indexed/);
  }
  assert.equal(requests, 0);
});

test('compact near-clue checks retain the existing token similarity rule without full question records', () => {
  const index = ResponseIndex.fromQuestions([first]);
  const duplicate = {...next, clue: first.clue};
  const previous = validatePool([first, duplicate]).flatMap(row => row.errors).filter(e => e.startsWith('near-duplicate-clue:'));
  const current = index.candidateErrors(duplicate).filter(e => e.startsWith('near-duplicate-clue:'));
  assert.deepEqual(current, previous);
  assert.deepEqual(index.candidateErrors(next), []);
  assert(index.candidateErrors({...next, acceptedAnswers: ['SIRA']}).includes('known-accepted-answer'));
});

test('reservation is idempotent, preserves history and rejects a conflicting word or changed content', async () => {
  const db = database(ResponseIndex.fromQuestions([first]).data);
  await reserveResponses(db, [next]);
  const saved = structuredClone(db.index);
  await reserveResponses(db, [next]);
  assert.deepEqual(db.index, saved);
  await assert.rejects(reserveResponses(db, [{...next, id: 'other'}]), /conflicts/);
  await assert.rejects(reserveResponses(db, [question('İNCİ', 'next', 'Yeni bir anlamı hedefleyen bambaşka açıklama.')]), /changed/);
  assert.deepEqual(db.index, saved);
  assert.equal(db.listeners, 0);
});

test('a competing publication is rechecked in the transaction, with no partially reserved batch', async () => {
  const db = database(ResponseIndex.fromQuestions([]).data);
  db.latest = ResponseIndex.fromQuestions([first]).data;
  await assert.rejects(reserveResponses(db, [next, {...first, id: 'competitor'}]), /conflicts/);
  assert.equal(Object.keys(db.index.uniqueResponses).length, 1);
  assert.equal(db.index.uniqueResponses[next.answerId], undefined);
  assert.equal(db.listeners, 0);
});

test('publication patches touch only new index entries and never reset the index or existing responses', () => {
  const updates = responseIndexUpdates([first, next]);
  assert.equal(updates[`${RESPONSE_INDEX_PATH}/uniqueResponses/${first.answerId}`], 'SIRA');
  assert.equal(updates[`${RESPONSE_INDEX_PATH}/acceptedResponses/${answerId('DİZİ')}`], 'DİZİ');
  assert.equal(updates[RESPONSE_INDEX_PATH], undefined);
  assert.equal(updates[`${RESPONSE_INDEX_PATH}/version`], undefined);
});

test('malformed or incomplete indexes fail closed; special valid question IDs cannot mutate prototypes', () => {
  for (const value of [null, {}, {version: 1, uniqueResponses: {wrong: 'SIRA'}}, {version: 1, uniqueResponses: {[first.answerId]: 'SIRA'}}]) {
    assert.throws(() => new ResponseIndex(value));
  }
  const special = question('SIRA', '__proto__', first.clue);
  const index = ResponseIndex.fromQuestions([special]);
  assert(Object.hasOwn(index.data.questions, '__proto__'));
  assert.equal(Object.getPrototypeOf(index.data.questions), Object.prototype);
  index.reserve(special);
  assert(index.excludes(special));
});
