import {createHash} from 'node:crypto';
import {LENGTHS, fingerprint, isPublished} from './content.js';
import {selectSet, capacityReport, PoolError} from './set_selector.js';

export function createQuestionSet(id, questions, publishedAtMs = Date.now(), {includeExamples = false} = {}) {
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(id) || questions.length !== 14 ||
      LENGTHS.some(length => questions.filter(q => q.letterCount === length).length !== 2) ||
      questions.some(q => !isPublished(q, {includeExamples}))) throw new Error('A published set requires 14 approved questions.');
  // Reuse the editorial set constraints: topics, all three difficulties and related answers.
  selectSet(questions, [], {includeExamples, random: () => 0.5});
  const ordered = [...questions].sort((a, b) => a.letterCount - b.letterCount);
  return {id, questionIds: ordered.map(q => q.id), fingerprint: fingerprint(ordered), publishedAtMs};
}

export function resolveQuestionSets(records, pool, options = {}) {
  const byId = new Map(pool.map(q => [q.id, q]));
  return Object.values(records ?? {}).map(raw => {
    const manifest = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!Array.isArray(manifest?.questionIds) || new Set(manifest.questionIds).size !== 14) throw new Error('Invalid set manifest.');
    const questions = manifest.questionIds.map(id => byId.get(id));
    if (questions.some(q => !q)) throw new Error('Published set contains missing questions.');
    const checked = createQuestionSet(manifest.id, questions, manifest.publishedAtMs, options);
    if (checked.fingerprint !== manifest.fingerprint) throw new Error('Published set fingerprint mismatch.');
    return {...checked, questions: checked.questionIds.map(id => byId.get(id))};
  });
}

function availableSets(sets, histories) {
  const completed = new Set(histories.flatMap(h => h.completedSetIds ?? []));
  return sets.filter(set => !completed.has(set.id));
}

export function availableSetIds(ids, histories = []) {
  const completed = new Set(histories.flatMap(h => h.completedSetIds ?? []));
  return ids.filter(id => !completed.has(id));
}

export function setIdCapacityReport(ids, histories = []) {
  const remaining = availableSetIds(ids, histories).length;
  // Every published classic set has exactly two questions per length.
  return {groups: LENGTHS.map(length => ({length, totalAnswers: ids.length * 2,
    approvedAnswers: ids.length * 2, publishedAnswers: ids.length * 2,
    remainingAnswers: remaining * 2, needed: 2})),
    availableSets: remaining, upperBoundSets: remaining, upperBoundDays: remaining / 3,
    blockedLengths: remaining ? [] : LENGTHS};
}

export function selectSetId(ids, histories, random = Math.random) {
  const available = availableSetIds(ids, histories);
  if (!available.length) throw new PoolError('sets-exhausted', setIdCapacityReport(ids, histories));
  return available[Math.min(available.length - 1, Math.floor(random() * available.length))];
}

export function setCapacityReport(sets, histories = [], options = {}) {
  const available = availableSets(sets, histories);
  const unique = new Map(available.flatMap(s => s.questions).map(q => [q.id, q]));
  const all=new Map(sets.flatMap(s=>s.questions).map(q=>[q.id,q]));
  const report = capacityReport([...all.values()], [], options);
  const groups=report.groups.map(group=>({...group,remainingAnswers:[...unique.values()].filter(q=>q.letterCount===group.length).length}));
  return {...report,groups,blockedLengths:groups.filter(g=>g.remainingAnswers<g.needed).map(g=>g.length),availableSets: available.length, upperBoundSets: available.length,
    upperBoundDays: available.length / 3, note: 'Complete published classic sets not completed by any participant.'};
}

export function selectPublishedSet(sets, histories, {random = Math.random, ...options} = {}) {
  const available = availableSets(sets, histories);
  if (!available.length) throw new PoolError('sets-exhausted', setCapacityReport(sets, histories, options));
  return available[Math.min(available.length - 1, Math.floor(random() * available.length))];
}

// A partial set can be resumed without changing its accepted questions or spending again.
export function fitsDraft(question, questions) {
  return questions.filter(q => q.letterCount === question.letterCount).length < 2 &&
    questions.filter(q => q.topic === question.topic).length < 5 &&
    questions.filter(q => q.difficulty === question.difficulty).length < 7 &&
    !questions.some(q => q.answerId === question.answerId || q.rootId === question.rootId ||
      q.relatedAnswerIds.includes(question.answerId) || question.relatedAnswerIds.includes(q.answerId)) &&
    (questions.length < 13 || new Set([...questions, question].map(q => q.difficulty)).size === 3) &&
    (questions.length < 13 || new Set([...questions, question].map(q => q.topic)).size >= 3);
}

// One-time migration: preserve imported sets; freeze other complete groups; leave leftovers private.
export function partitionExistingQuestions(pool) {
  const remaining = new Map(pool.map(q => [q.id, q]));
  const sets = {};
  const imported = new Map();
  for (const q of pool) {
    const match = /^(initial_\d{3})_q\d{2}$/.exec(q.id);
    if (match) imported.set(match[1], [...(imported.get(match[1]) ?? []), q]);
  }
  for (const [id, questions] of imported) {
    sets[id] = createQuestionSet(id, questions);
    for (const q of questions) remaining.delete(q.id);
  }
  while (remaining.size >= 14) {
    let questions;
    try { ({questions} = selectSet([...remaining.values()], [], {random: () => 0.5})); }
    catch (error) {if (error instanceof PoolError) break; throw error;}
    const id = `initial_pool_${createHash('sha256').update(questions.map(q => q.id).sort().join('\n')).digest('hex').slice(0, 24)}`;
    sets[id] = createQuestionSet(id, questions);
    for (const q of questions) remaining.delete(q.id);
  }
  return {sets, backlog: Object.fromEntries([...remaining.values()].map(q => [q.id, JSON.stringify({...q, publication: 'unpublished'})]))};
}
