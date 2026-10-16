import {createHash} from 'node:crypto';
import {capacityReport, PoolError, selectSet} from './set_selector.js';

export const QUESTION_MS = 25000;
// Shorter than the reservation grace period: stale snapshots cannot outlive a
// concurrently allocated game's last newly shown answer.
export const PREPARATION_MS = 25000;
export const roomKey = room => createHash('sha256').update(`${room.id}:${room.createdAt}:${room.hostId}`).digest('hex');

export function validateHistory(history) {
  for (const key of ['seenAnswerIds', 'seenQuestionIds']) {
    const values = history?.[key];
    if (!Array.isArray(values) || values.length > 50000 || values.some(v => typeof v !== 'string' || !/^[A-Za-z0-9_-]{1,100}$/.test(v))) {
      throw new Error('invalid-history');
    }
  }
  return {seenAnswerIds: [...new Set(history.seenAnswerIds)], seenQuestionIds: [...new Set(history.seenQuestionIds)]};
}

export function activeAllocations(state, now) {
  return Object.fromEntries(Object.entries(state?.sessions ?? {}).filter(([, s]) => s.expiresAtMs > now));
}

// One bounded RTDB transaction covers all players. No per-user permanent history is stored here.
export function allocate(state, {sessionId, roomId, mode, participantIds, histories, pool, now, includeExamples = false}) {
  const sessions = activeAllocations(state, now);
  if (sessions[sessionId]) {
    const session = {...sessions[sessionId]};
    sessions[sessionId] = session;
    // Recover an allocation whose room write was delayed/failed. A room that
    // already contains this session keeps its original clock in the room CAS.
    if (session.startsAtMs <= now) {
      session.startsAtMs = now + 4000;
      session.expiresAtMs = session.startsAtMs + session.questions.length * QUESTION_MS + 30000;
    }
    return {state: {sessions}, session};
  }
  if (Object.keys(sessions).length >= 300) throw new PoolError('allocation-capacity', null);
  const reserved = Object.values(sessions).filter(s => s.participantIds.some(uid => participantIds.includes(uid)));
  const blocked = reserved.map(s => ({reservedAnswerIds: s.questions.map(q => q.answerId), reservedQuestionIds: s.questions.map(q => q.id)}));
  const selected = selectSet(pool, [...histories, ...blocked], {mode, includeExamples});
  const startsAtMs = now + 4000;
  const session = {sessionId, roomId, mode, participantIds, startsAtMs,
    expiresAtMs: startsAtMs + selected.questions.length * QUESTION_MS + 30000,
    fingerprint: selected.fingerprint,
    questions: selected.questions.map(({id, answerId, answer, clue, letterCount, acceptedAnswers}) =>
      ({id, answerId, answer, clue, letterCount, ...(acceptedAnswers?.length ? {acceptedAnswers} : {})}))};
  sessions[sessionId] = session;
  return {state: {sessions}, session};
}

export function release(state, sessionId, now) {
  const sessions = activeAllocations(state, now);
  delete sessions[sessionId];
  return {sessions};
}

export {capacityReport};
