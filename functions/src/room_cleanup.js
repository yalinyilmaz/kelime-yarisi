import {transaction} from './database_transaction.js';
import {ServiceError} from './question_service.js';

export const OFFLINE_ROOM_MS = 60 * 60 * 1000;

// Re-read inside a transaction: a delayed disconnect event must never delete a
// room that another player has joined or reconnected to in the meantime.
export async function cleanupEmptyRoom(roomRef, now = Date.now()) {
  return transaction(roomRef, room => {
    if (!room) return undefined;
    const players = Object.values(room.players ?? {});
    if (players.length === 0) return null;
    if (players.some(p => p?.isOnline === true)) {
      if (room.offlineSinceAt == null) return undefined;
      const next = {...room};
      delete next.offlineSinceAt;
      return next;
    }
    if (!Number.isFinite(room.offlineSinceAt)) return {...room, offlineSinceAt: now};
    return now - room.offlineSinceAt >= OFFLINE_ROOM_MS ? null : undefined;
  });
}

export async function cleanupOfflineRooms(database, now = Date.now()) {
  const expired = await database.ref('rooms').orderByChild('offlineSinceAt')
    .startAt(1).endAt(now - OFFLINE_ROOM_MS).limitToFirst(100).get();
  await Promise.all(Object.keys(expired.val() ?? {}).map(id =>
    cleanupEmptyRoom(database.ref(`rooms/${id}`), now)));
}

export async function leaveRoom(database, uid, {roomId}, now = Date.now()) {
  if (!uid) throw new ServiceError('unauthenticated', 'Oturum açılmalı.');
  if (typeof roomId !== 'string' || !/^[a-hj-np-z]{3}[2-9]{3}$/.test(roomId)) {
    throw new ServiceError('invalid-argument', 'Oda kodu geçersiz.');
  }
  const result = await transaction(database.ref(`rooms/${roomId}`), room => {
    // Retries after the membership/room was already removed are harmless.
    if (!room?.players?.[uid]) return undefined;
    const next = structuredClone(room);
    delete next.players[uid];
    const remaining = Object.keys(next.players);
    if (remaining.length === 0) return null;
    next.playerCount = remaining.length;
    if (next.hostId === uid) {
      next.hostId = remaining.find(id => next.players[id].isOnline === true) ?? remaining[0];
      for (const id of remaining) next.players[id].isHost = id === next.hostId;
    }
    if (remaining.some(id => next.players[id].isOnline === true)) delete next.offlineSinceAt;
    else if (!Number.isFinite(next.offlineSinceAt)) next.offlineSinceAt = now;
    return next;
  });
  return {committed: result.committed};
}
