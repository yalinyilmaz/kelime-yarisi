import {transaction} from './database_transaction.js';
import {activeAllocations, allocate, PREPARATION_MS, release, roomKey, validateHistory} from './allocation.js';
import {capacityReport, PoolError} from './set_selector.js';
import {setCapacityReport} from './question_sets.js';

export class ServiceError extends Error {
  constructor(code, message, details) {super(message); this.code = code; this.details = details;}
}

export class QuestionService {
  constructor({database, pool, now = Date.now, includeExamples = false, allowSolo = false,allowDebugSolo=false,loadPool,loadSets}) {
    Object.assign(this, {database, pool, now, includeExamples, allowSolo,allowDebugSolo,loadPool,loadSets});
  }
  async room(id, uid) {
    if (!uid) throw new ServiceError('unauthenticated', 'Oturum açılmalı.');
    if (typeof id !== 'string' || !/^[a-hj-np-z]{3}[2-9]{3}$/.test(id)) throw new ServiceError('invalid-argument', 'Oda kodu geçersiz.');
    const room = (await this.database.ref(`rooms/${id}`).get()).val();
    if (!room?.players?.[uid]) throw new ServiceError('permission-denied', 'Oda üyeliği gerekli.');
    if (!Number.isFinite(room.createdAt)) throw new ServiceError('failed-precondition', 'Oda verisi eksik.');
    return {...room, id};
  }
  async prepare(uid, {roomId, history}) {
    const room = await this.room(roomId, uid);
    if (room.questionEngine !== 'pool-v1') throw new ServiceError('failed-precondition', 'Bu oda örnek sabit set kullanıyor. Yeni havuz odası oluşturun.');
    if(this.loadSets&&room.gameMode!=='classic')throw new ServiceError('failed-precondition','Yeni bir klasik oyun odası oluşturun.');
    if (room.status !== 'lobby') throw new ServiceError('failed-precondition', 'Hazırlık yalnızca lobide yapılabilir.');
    let checked;
    try {checked = validateHistory(history);} catch {throw new ServiceError('invalid-argument', 'Geçmiş biçimi veya boyutu geçersiz.');}
    await this.database.ref(`questionPreparations/${uid}`).set({roomKey: roomKey(room), roomId, ...checked, expiresAtMs: this.now() + PREPARATION_MS});
    if(this.loadSets)return setCapacityReport(await this.loadSets(),[checked],{includeExamples:this.includeExamples});
    const allocations = activeAllocations((await this.database.ref('questionAllocations').get()).val(), this.now());
    const reservations = Object.values(allocations).filter(s => s.participantIds.includes(uid))
      .map(s => ({reservedAnswerIds: s.questions.map(q => q.answerId), reservedQuestionIds: s.questions.map(q => q.id)}));
    const pool=this.loadPool?await this.loadPool():this.pool;
    return capacityReport(pool, [checked, ...reservations], {mode: room.gameMode, includeExamples: this.includeExamples});
  }
  async start(uid, {roomId,debugSolo=false}) {
    const room = await this.room(roomId, uid);
    if (room.hostId !== uid) throw new ServiceError('permission-denied', 'Oyunu oda sahibi başlatır.');
    if (room.questionEngine !== 'pool-v1') throw new ServiceError('failed-precondition', 'Bu oda soru havuzu odası değil.');
    const sessionId = roomKey(room);
    if (room.questionSetId === `pool-v1:${sessionId}`) return {sessionId};
    if (room.status !== 'lobby' || !['classic', 'quick'].includes(room.gameMode)) throw new ServiceError('failed-precondition', 'Oda başlatılamaz.');
    const participantIds = Object.keys(room.players).sort();
    if(this.loadSets&&room.gameMode!=='classic')throw new ServiceError('failed-precondition','Yalnız klasik oyun destekleniyor.');
    const solo = (this.allowSolo || (this.allowDebugSolo&&debugSolo===true)) && participantIds.length === 1;
    if (!solo && (participantIds.length !== room.targetPlayerCount || participantIds.some(id => !room.players[id].isReady || !room.players[id].isOnline))) {
      throw new ServiceError('failed-precondition', 'Tüm oyuncular hazır ve bağlı olmalı.');
    }
    const preparations = await Promise.all(participantIds.map(async id => (await this.database.ref(`questionPreparations/${id}`).get()).val()));
    if (preparations.some(p => p?.roomKey !== sessionId || p.expiresAtMs <= this.now())) {
      const latest = await this.room(roomId, uid);
      if (latest.questionSetId === `pool-v1:${sessionId}`) return {sessionId};
      throw new ServiceError('failed-precondition', 'Soru geçmişi hazırlığı eksik veya süresi doldu. Hazır durumunu yenileyin.');
    }
    let allocationError;
    const sets=this.loadSets?await this.loadSets():undefined;
    const pool=sets?sets.flatMap(s=>s.questions):this.loadPool?await this.loadPool():this.pool;
    const result = await transaction(this.database.ref('questionAllocations'), state => {
      try {
        allocationError = null;
        if (preparations.some(p => p.expiresAtMs <= this.now())) {
          throw new ServiceError('failed-precondition', 'Geçmiş hazırlığının süresi doldu. Hazır durumunu yenileyin.');
        }
        return allocate(state, {sessionId, roomId, mode: room.gameMode, participantIds,
          histories: preparations, pool,sets, now: this.now(), includeExamples: this.includeExamples}).state;
      } catch (e) {allocationError = e; return undefined;}
    });
    if (!result.committed) {
      if (allocationError instanceof PoolError) throw new ServiceError('resource-exhausted', 'Yeni ortak soru seti için uygun içerik yetersiz.', {reason: allocationError.code, capacity: allocationError.report});
      throw allocationError ?? new ServiceError('aborted', 'Soru seti ayrılamadı.');
    }
    const session = result.snapshot.val().sessions[sessionId];
    const committed = await transaction(this.database.ref(`rooms/${roomId}`), current => {
      if (!current || roomKey({...current, id: roomId}) !== sessionId) return undefined;
      if (current.questionSetId === `pool-v1:${sessionId}`) return current;
      if (current.status !== 'lobby' || current.gameMode !== room.gameMode ||
          JSON.stringify(Object.keys(current.players ?? {}).sort()) !== JSON.stringify(participantIds) ||
          (!solo && participantIds.some(id => !current.players[id].isReady || !current.players[id].isOnline))) return undefined;
      return {...current, questionSetId: `pool-v1:${sessionId}`, ...(session.contentSetId?{contentSetId:session.contentSetId}:{}),questions: session.questions,
        startsAtMs: session.startsAtMs, gameplayVersion: 'race-v1', status: 'countdown',
        race: {questionIndex: 0, startedAtMs: session.startsAtMs},
        questionFingerprint: session.fingerprint, questionOrigin: this.includeExamples ? 'example' : 'production'};
    });
    if (!committed.committed) {
      await transaction(this.database.ref('questionAllocations'), state => release(state, sessionId, this.now()));
      throw new ServiceError('aborted', 'Oyuncular değişti. Hazır durumunu yenileyip tekrar deneyin.');
    }
    // Prepared history is transient. Clearing uses compare-and-delete to protect a newer room.
    await Promise.all(participantIds.map(id => transaction(this.database.ref(`questionPreparations/${id}`), p => p?.roomKey === sessionId ? null : undefined)));
    return {sessionId};
  }
  async cleanup() {
    const now = this.now();
    await transaction(this.database.ref('questionAllocations'), state => ({sessions: Object.fromEntries(Object.entries(state?.sessions ?? {}).filter(([, s]) => s.expiresAtMs > now))}));
    const snapshot = await this.database.ref('questionPreparations').get();
    const preparations = snapshot.val() ?? {};
    await Promise.all(Object.keys(preparations).map(uid => transaction(this.database.ref(`questionPreparations/${uid}`), p => p?.expiresAtMs <= now ? null : undefined)));
  }
}
