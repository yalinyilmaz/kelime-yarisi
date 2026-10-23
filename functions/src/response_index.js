import {isDeepStrictEqual} from 'node:util';
import {answerId, normalizeWord, validateQuestion} from './content.js';
import {transaction} from './database_transaction.js';

export const RESPONSE_INDEX_PATH = 'questionPool/generationIndex';
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,100}$/.test(value);
const words = value => [...new Set(normalizeWord(value).match(/[A-ZÇĞİÖŞÜ]+/gu) ?? [])].sort();
const validAnswer = value => typeof value === 'string' && value === normalizeWord(value) &&
  /^[A-ZÇĞİÖŞÜ]+(?: [A-ZÇĞİÖŞÜ]+)?$/u.test(value) &&
  [...value.replaceAll(' ', '')].length >= 4 && [...value.replaceAll(' ', '')].length <= 10;
const summary = q => ({answerId: q.answerId, clueTokens: words(q.clue).join(' '),
  digest: q.review.digest, accepted: JSON.stringify(q.acceptedAnswers ?? [])});

// A private, compact catalogue. Source evidence, prompts, reviews and full
// question records stay in published; only novelty/near-clue checks live here.
export class ResponseIndex {
  constructor(raw) {
    if (raw?.version !== 1) throw new Error('Response index missing; backfill before generation.');
    this.data = structuredClone({version: 1, uniqueResponses: raw.uniqueResponses ?? {},
      acceptedResponses: raw.acceptedResponses ?? {}, questions: raw.questions ?? {}});
    const {uniqueResponses, acceptedResponses, questions} = this.data;
    for (const entries of [uniqueResponses, acceptedResponses]) {
      if (!entries || typeof entries !== 'object' || Array.isArray(entries) ||
          Object.entries(entries).some(([id, answer]) => !validAnswer(answer) || answerId(answer) !== id)) {
        throw new Error('Invalid response index.');
      }
    }
    if (!questions || typeof questions !== 'object' || Array.isArray(questions)) throw new Error('Invalid question index.');
    const owners = new Set();
    this.clues = new Map();
    for (const [id, entry] of Object.entries(questions)) {
      if (!validId(id) || !Object.hasOwn(uniqueResponses, entry?.answerId) || owners.has(entry.answerId) ||
          typeof entry.clueTokens !== 'string' || words(entry.clueTokens).join(' ') !== entry.clueTokens ||
          !/^[a-f0-9]{64}$/.test(entry.digest ?? '')) throw new Error('Invalid indexed question.');
      let aliases;
      try { aliases = JSON.parse(entry.accepted); } catch { throw new Error('Invalid indexed alternatives.'); }
      if (!Array.isArray(aliases) || aliases.some(a => !validAnswer(a) || acceptedResponses[answerId(a)] !== a)) {
        throw new Error('Invalid indexed alternatives.');
      }
      owners.add(entry.answerId);
      this.clues.set(id, new Set(entry.clueTokens.split(' ').filter(Boolean)));
    }
    if (owners.size !== Object.keys(uniqueResponses).length) throw new Error('Incomplete response index.');
    this.counts = new Map();
    for (const answer of Object.values(uniqueResponses)) {
      const length = [...answer.replaceAll(' ', '')].length;
      this.counts.set(length, (this.counts.get(length) ?? 0) + 1);
    }
  }

  static fromQuestions(questions) {
    const raw = {version: 1, uniqueResponses: {}, acceptedResponses: {}, questions: {}};
    for (const q of questions) {
      if (validateQuestion(q).length || q.review.status !== 'approved') throw new Error('Unreviewed question cannot enter the response index.');
      if (Object.hasOwn(raw.questions, q.id) || Object.hasOwn(raw.uniqueResponses, q.answerId)) throw new Error('Duplicate indexed identity.');
      raw.uniqueResponses[q.answerId] = q.answer;
      for (const alias of q.acceptedAnswers ?? []) raw.acceptedResponses[answerId(alias)] = alias;
      Object.defineProperty(raw.questions, q.id, {value: summary(q), enumerable: true, configurable: true, writable: true});
    }
    return new ResponseIndex(raw);
  }

  hasAnswer(id) { return Object.hasOwn(this.data.uniqueResponses, id) || Object.hasOwn(this.data.acceptedResponses, id); }
  count(length) { return this.counts.get(length) ?? 0; }
  excludes(source) {
    return this.hasAnswer(source.answerId) || Object.hasOwn(this.data.questions, source.id) ||
      (source.acceptedAnswers ?? []).some(a => this.hasAnswer(answerId(a)));
  }
  candidateErrors(q) {
    const errors = [];
    if (Object.hasOwn(this.data.questions, q.id)) errors.push('duplicate-question-id');
    if (this.hasAnswer(q.answerId)) errors.push('duplicate-answer');
    if ((q.acceptedAnswers ?? []).some(a => this.hasAnswer(answerId(a)))) errors.push('known-accepted-answer');
    const candidate = new Set(words(q.clue));
    for (const [id, previous] of this.clues) {
      if (previous.size < 4) continue;
      const intersection = [...previous].filter(word => candidate.has(word)).length;
      if (intersection / (previous.size + candidate.size - intersection) >= 0.85) errors.push(`near-duplicate-clue:${id}`);
    }
    return errors;
  }

  // Replays of an already reserved outbox are harmless, but changed content or
  // another question claiming the same answer must never overwrite the claim.
  reserve(q) {
    const entry = summary(q), previous = Object.hasOwn(this.data.questions, q.id) ? this.data.questions[q.id] : undefined;
    if (previous) {
      if (!isDeepStrictEqual(previous, entry)) throw new Error('Indexed question changed.');
      return;
    }
    if (validateQuestion(q).length || q.review.status !== 'approved' || this.candidateErrors(q).length) {
      throw new Error('Question conflicts with the response index.');
    }
    this.data.uniqueResponses[q.answerId] = q.answer;
    this.counts.set(q.letterCount, this.count(q.letterCount) + 1);
    for (const alias of q.acceptedAnswers ?? []) this.data.acceptedResponses[answerId(alias)] = alias;
    this.data.questions = {...this.data.questions, [q.id]: entry};
    this.clues.set(q.id, new Set(entry.clueTokens.split(' ').filter(Boolean)));
  }
}

export async function loadResponseIndex(database, bundled = []) {
  const index = new ResponseIndex((await database.ref(RESPONSE_INDEX_PATH).get()).val());
  if (bundled.some(q => index.data.uniqueResponses[q.answerId] !== q.answer)) {
    throw new Error('Response index does not cover bundled questions; backfill required.');
  }
  return index;
}

export async function reserveResponses(database, questions) {
  let failure;
  const result = await transaction(database.ref(RESPONSE_INDEX_PATH), raw => {
    try {
      failure = undefined;
      const index = new ResponseIndex(raw);
      for (const q of questions) index.reserve(q);
      return index.data;
    } catch (error) { failure = error; return undefined; }
  });
  if (!result.committed) throw failure ?? new Error('Response reservation failed.');
  return new ResponseIndex(result.snapshot.val());
}

// Publication patches update each question and its index entries atomically;
// never replace the entire index with an offline/stale snapshot.
export function responseIndexUpdates(questions) {
  const updates = {};
  for (const q of questions) {
    updates[`${RESPONSE_INDEX_PATH}/uniqueResponses/${q.answerId}`] = q.answer;
    for (const alias of q.acceptedAnswers ?? []) updates[`${RESPONSE_INDEX_PATH}/acceptedResponses/${answerId(alias)}`] = alias;
    updates[`${RESPONSE_INDEX_PATH}/questions/${q.id}`] = summary(q);
  }
  return updates;
}
