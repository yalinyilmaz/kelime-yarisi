import {LENGTHS, fingerprint, isPublished, validateQuestion} from './content.js';

export class PoolError extends Error {
  constructor(code, report) {
    super(code);
    this.code = code;
    this.report = report;
  }
}

export function capacityReport(pool, histories = [], {mode = 'classic', gamesPerDay = 3, includeExamples = false} = {}) {
  if (!['classic', 'quick'].includes(mode) || !(gamesPerDay > 0)) throw new Error('Invalid capacity options.');
  const needed = mode === 'classic' ? 2 : 1;
  const blockedAnswers = new Set(histories.flatMap(h => [...(h.seenAnswerIds ?? []), ...(h.reservedAnswerIds ?? [])]));
  const blockedQuestions = new Set(histories.flatMap(h => [...(h.seenQuestionIds ?? []), ...(h.reservedQuestionIds ?? [])]));
  const groups = LENGTHS.map(length => {
    const records = pool.filter(q => q.letterCount === length);
    const published = records.filter(q => isPublished(q, {includeExamples}));
    const eligible = published.filter(q => !blockedAnswers.has(q.answerId) && !blockedQuestions.has(q.id));
    return {length, needed, totalAnswers: new Set(records.map(q => q.answerId)).size,
      approvedAnswers: new Set(records.filter(q => q.review?.status === 'approved' && validateQuestion(q).length === 0).map(q => q.answerId)).size,
      publishedAnswers: new Set(published.map(q => q.answerId)).size,
      remainingAnswers: new Set(eligible.map(q => q.answerId)).size};
  });
  const upperBoundSets = Math.min(...groups.map(g => Math.floor(g.remainingAnswers / needed)));
  return {groups, blockedLengths: groups.filter(g => g.remainingAnswers < needed).map(g => g.length),
    upperBoundSets, upperBoundDays: upperBoundSets / gamesPerDay,
    note: 'Upper bound before topic, difficulty and related-word constraints; not a content guarantee.'};
}

export function selectSet(pool, histories, {mode = 'classic', random = Math.random, includeExamples = false, searchBudget = 50000} = {}) {
  const report = capacityReport(pool, histories, {mode, includeExamples});
  if (report.blockedLengths.length) throw new PoolError('pool-exhausted', report);
  const seenAnswers = new Set(histories.flatMap(h => [...(h.seenAnswerIds ?? []), ...(h.reservedAnswerIds ?? [])]));
  const seenQuestions = new Set(histories.flatMap(h => [...(h.seenQuestionIds ?? []), ...(h.reservedQuestionIds ?? [])]));
  const required = mode === 'classic' ? 2 : 1;
  const count = required * LENGTHS.length;
  const topicLimit = Math.ceil(count / 3);
  const difficultyLimit = Math.ceil(count / 2);
  const groups = new Map(LENGTHS.map(length => [length, pool
    .filter(q => q.letterCount === length && isPublished(q, {includeExamples}) && !seenAnswers.has(q.answerId) && !seenQuestions.has(q.id))
    .map(q => ({q, order: random()})).sort((a, b) => a.order - b.order).map(x => x.q)]));
  // Solve scarce buckets first, then order by length for the existing scoring rules.
  const slots = [...LENGTHS].sort((a, b) => groups.get(a).length - groups.get(b).length).flatMap(length => Array(required).fill(length));
  const selected = [];
  let visited = 0;
  const conflicts = q => selected.some(other => other.answerId === q.answerId || other.rootId === q.rootId ||
    other.relatedAnswerIds.includes(q.answerId) || q.relatedAnswerIds.includes(other.answerId));
  const tally = (field, value) => selected.filter(q => q[field] === value).length;
  function search(index) {
    if (++visited > searchBudget) throw new PoolError('selection-budget-exceeded', report);
    if (index === slots.length) return new Set(selected.map(q => q.topic)).size >= 3 && new Set(selected.map(q => q.difficulty)).size === 3;
    for (const q of groups.get(slots[index])) {
      if (conflicts(q) || tally('topic', q.topic) >= topicLimit || tally('difficulty', q.difficulty) >= difficultyLimit) continue;
      selected.push(q);
      if (search(index + 1)) return true;
      selected.pop();
    }
    return false;
  }
  if (!search(0)) throw new PoolError('balance-unavailable', report);
  const questions = selected.sort((a, b) => a.letterCount - b.letterCount);
  return {questions, fingerprint: fingerprint(questions), capacity: report};
}
