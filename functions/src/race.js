import {transaction} from './database_transaction.js';
import {ServiceError} from './question_service.js';

export const QUESTION_MS = 25000;
export const REVEAL_MS = 2000;
export const initialRace = startsAtMs => ({questionIndex: 0, startedAtMs: startsAtMs});

// Matches Flutter's Turkish/ASCII tolerance, including two-word answers.
const letters = text => text.normalize('NFC').replaceAll('i', 'İ').replaceAll('ı', 'I')
  .toUpperCase().replace(/\s+/gu, '');
const comparison = text => letters(text).replace(/[ÇĞİÖŞÜ]/gu, c =>
  ({Ç:'C', Ğ:'G', İ:'I', Ö:'O', Ş:'S', Ü:'U'})[c]).replace(/[\u0306-\u0308\u0327]/gu, '');
const valueOf = (room, index) => (letters(room.questions[index].answer).length -
  (room.hints?.[index]?.revealedCount ?? 0)) * 100;

function score(room, uid, outcome, at) {
  const index = room.race.questionIndex;
  const previous = room.progress?.[uid] ?? {};
  if ((previous.questionIndex ?? 0) > index) return; // Exactly one attempt per player/question.
  const delta = outcome === 'correct' ? valueOf(room, index) : outcome === 'beaten' ? 0 : -valueOf(room, index);
  room.progress ??= {};
  room.progress[uid] = {
    questionIndex: index + 1,
    score: (previous.score ?? 0) + delta,
    correctCount: (previous.correctCount ?? 0) + (outcome === 'correct' ? 1 : 0),
    wrongCount: (previous.wrongCount ?? 0) + (['wrong', 'timeout'].includes(outcome) ? 1 : 0),
    skippedCount: (previous.skippedCount ?? 0) + (outcome === 'beaten' ? 1 : 0),
    finished: index + 1 === room.questions.length,
    lastOutcome: outcome, lastScoreDelta: delta, updatedAtMs: at,
  };
}

function resolve(room, winnerId, at) {
  for (const uid of Object.keys(room.players)) {
    score(room, uid, winnerId ? (uid === winnerId ? 'correct' : 'beaten') : 'timeout', at);
  }
  Object.assign(room.race, {resolvedAtMs: at, nextAtMs: at + REVEAL_MS,
    reason: winnerId ? 'correct' : 'timeout',
    ...(winnerId ? {winnerId, winnerName: room.players[winnerId].displayName} : {})});
}

// Pure reducer: RTDB reruns it against the latest committed room on contention.
export function reduceRace(current, uid, {action = 'sync', questionIndex, input, expectedRevealedCount, expectedHintCount} = {}, now) {
  if (!current?.players?.[uid]) throw new ServiceError('permission-denied', 'Oda üyeliği gerekli.');
  if (current.gameplayVersion !== 'race-v1' || !current.race || !current.questions?.length) {
    throw new ServiceError('failed-precondition', 'Yeni bir yarış odası oluşturun.');
  }
  const room = structuredClone(current);
  if (room.status === 'results' || now < room.race.startedAtMs) return room;
  if (!['countdown', 'playing'].includes(room.status)) throw new ServiceError('failed-precondition', 'Oyun başlamadı.');
  room.status = 'playing';
  // Reconnect after background/disconnection catches up without extending deadlines.
  while (room.race.questionIndex < room.questions.length) {
    const race = room.race;
    if (!race.nextAtMs && now >= race.startedAtMs + QUESTION_MS) resolve(room, null, race.startedAtMs + QUESTION_MS);
    if (!race.nextAtMs || now < race.nextAtMs) break;
    room.race = {questionIndex: race.questionIndex + 1, startedAtMs: race.nextAtMs};
  }
  const index = room.race.questionIndex;
  if (index === room.questions.length) {
    room.status = 'results';
    return room;
  }
  if (action === 'sync' || questionIndex !== index || room.race.nextAtMs ||
      (room.progress?.[uid]?.questionIndex ?? 0) > index) return room;
  if (action === 'clueHint') {
    const usage = room.clueHintUsage?.[uid] ?? {};
    const used = usage[index] ?? 0;
    const total = Object.values(usage).reduce((sum, count) => sum + count, 0);
    // Expected count makes retries and simultaneous taps spend at most one right.
    if (used !== expectedHintCount || used >= 2 || total >= 10 ||
        room.questions[index].hints?.length !== 2) return room;
    room.clueHintUsage ??= {};
    room.clueHintUsage[uid] = {...usage, [index]:used + 1};
  } else if (action === 'hint') {
    const old = room.hints?.[index] ?? {questionIndex: index, revealedCount: 0};
    if (old.revealedCount !== expectedRevealedCount) return room;
    if (old.revealedCount >= letters(room.questions[index].answer).length - 1 || old.firstVoterId === uid) return room;
    const next = room.targetPlayerCount <= 3 || old.firstVoterId
      ? {questionIndex: index, revealedCount: old.revealedCount + 1}
      : {...old, firstVoterId: uid};
    room.hints ??= {};
    room.hints[index] = next;
  } else if (action === 'giveUp') {
    score(room, uid, 'wrong', now);
  } else if (action === 'answer') {
    const question = room.questions[index];
    if (letters(input).length !== letters(question.answer).length) throw new ServiceError('invalid-argument', 'Tüm boş harfleri doldur.');
    if ([question.answer, ...(question.acceptedAnswers ?? [])].some(a => comparison(a) === comparison(input))) {
      resolve(room, uid, now);
    } else score(room, uid, 'wrong', now);
  }
  return room;
}

export class RaceService {
  constructor({database, now = Date.now, demoQuestions, allowDebugSolo = false}) {
    Object.assign(this, {database, now, demoQuestions, allowDebugSolo});
  }

  reference(uid, roomId) {
    if (!uid) throw new ServiceError('unauthenticated', 'Oturum açılmalı.');
    if (typeof roomId !== 'string' || !/^[a-hj-np-z]{3}[2-9]{3}$/.test(roomId)) throw new ServiceError('invalid-argument', 'Oda kodu geçersiz.');
    return this.database.ref(`rooms/${roomId}`);
  }

  async commit(reference, reduce) {
    let failure;
    const result = await transaction(reference, current => {
      try {failure = null; return reduce(current);}
      catch (error) {failure = error; return undefined;}
    });
    if (!result.committed && failure) throw failure;
    return {committed: result.committed};
  }

  async startDemo(uid, {roomId, debugSolo = false}) {
    return this.commit(this.reference(uid, roomId), room => {
      if (!room || room.hostId !== uid) throw new ServiceError('permission-denied', 'Oyunu oda sahibi başlatır.');
      if (room.gameplayVersion === 'race-v1') return room;
      if (room.questionEngine === 'pool-v1' || room.status !== 'lobby' || room.gameMode !== 'classic') {
        throw new ServiceError('failed-precondition', 'Örnek oyun başlatılamaz.');
      }
      const players = Object.values(room.players ?? {});
      const solo = this.allowDebugSolo && debugSolo === true && players.length === 1;
      if (!solo && (players.length !== room.targetPlayerCount || players.some(p => !p.isReady || !p.isOnline))) {
        throw new ServiceError('failed-precondition', 'Tüm oyuncular hazır ve bağlı olmalı.');
      }
      const startsAtMs = this.now() + 4000;
      return {...room, startsAtMs, gameplayVersion: 'race-v1', status: 'countdown',
        questionSetId: `${room.gameMode}-v1`,
        questions: this.demoQuestions,
        race: initialRace(startsAtMs)};
    });
  }

  async play(uid, data) {
    if (!['sync', 'answer', 'hint', 'clueHint', 'giveUp'].includes(data.action) ||
        (data.action !== 'sync' && (!Number.isInteger(data.questionIndex) || data.questionIndex < 0 || data.questionIndex > 13)) ||
        (data.action === 'hint' && (!Number.isInteger(data.expectedRevealedCount) || data.expectedRevealedCount < 0 || data.expectedRevealedCount > 9)) ||
        (data.action === 'clueHint' && (!Number.isInteger(data.expectedHintCount) || data.expectedHintCount < 0 || data.expectedHintCount > 1)) ||
        (data.action === 'answer' && (typeof data.input !== 'string' || data.input.length > 64))) {
      throw new ServiceError('invalid-argument', 'Oyun işlemi geçersiz.');
    }
    return this.commit(this.reference(uid, data.roomId), current => reduceRace(current, uid, data, this.now()));
  }
}
