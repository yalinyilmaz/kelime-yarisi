import {randomUUID} from 'node:crypto';
import {transaction} from './database_transaction.js';
import {ServiceError} from './question_service.js';

const validId = value => typeof value === 'string' && /^[0-9a-f-]{36}$/.test(value);
const requireAuth = uid => {
  if (!uid) throw new ServiceError('unauthenticated', 'Oturum açılmalı.');
};

// Room keys encode invitation codes. Never expose those keys in the directory.
// Legacy rooms get an opaque, server-owned handle the first time they are listed.
export async function listRooms(database, uid) {
  requireAuth(uid);
  const snapshot = await database.ref('rooms').orderByChild('status').equalTo('lobby').get();
  const rooms = [];
  for (const [roomId, original] of Object.entries(snapshot.val() ?? {})) {
    let room = original;
    if (!validId(room.directoryId)) {
      const directoryId = randomUUID();
      const result = await transaction(database.ref(`rooms/${roomId}`), current => {
        if (!current || current.status !== 'lobby') return undefined;
        return validId(current.directoryId) ? current : {...current, directoryId};
      });
      room = result.snapshot.val();
    }
    if (!room || room.status !== 'lobby') continue;
    const members = Object.values(room.players ?? {});
    if (!members.some(player => player.isOnline === true)) continue;
    rooms.push({
      id: room.directoryId,
      name: room.name,
      visibility: room.visibility === 'public' ? 'public' : 'private',
      playerCount: members.length,
      capacity: room.targetPlayerCount,
    });
  }
  return {rooms};
}

export async function joinListedRoom(database, uid, {directoryId, displayName, roomCode}, now = Date.now()) {
  requireAuth(uid);
  if (!validId(directoryId) || typeof displayName !== 'string' ||
      displayName.trim().length < 2 || displayName.trim().length > 24) {
    throw new ServiceError('invalid-argument', 'Oda veya oyuncu bilgisi geçersiz.');
  }
  const matches = await database.ref('rooms').orderByChild('directoryId').equalTo(directoryId).limitToFirst(1).get();
  const roomId = Object.keys(matches.val() ?? {})[0];
  if (!roomId) throw new ServiceError('not-found', 'Bu oda artık açık değil. Listeyi yenileyin.');
  const code = typeof roomCode === 'string' ? roomCode.toUpperCase().replace(/[\s-]/g, '') : '';
  let failure;
  const result = await transaction(database.ref(`rooms/${roomId}`), room => {
    failure = undefined;
    if (!room || room.directoryId !== directoryId) {
      failure = new ServiceError('not-found', 'Bu oda artık açık değil.');
      return undefined;
    }
    // Idempotent retries cannot add a member twice or reset readiness/host status.
    if (room.players?.[uid]) return room;
    if (room.status !== 'lobby') {
      failure = new ServiceError('failed-precondition', 'Bu odada oyun başlamış.');
      return undefined;
    }
    if (room.visibility !== 'public' && code !== room.code?.replaceAll('-', '')) {
      failure = new ServiceError('permission-denied', 'Oda kodu eşleşmedi. Kodu kontrol edin.');
      return undefined;
    }
    const count = Object.keys(room.players ?? {}).length;
    if (count >= room.targetPlayerCount) {
      failure = new ServiceError('resource-exhausted', 'Bu oda dolu. Başka bir oda seçin.');
      return undefined;
    }
    const next = {...room, players: {...room.players, [uid]: {
      displayName: displayName.trim(), isHost: false, isReady: false, isOnline: true, lastSeenAt: now,
    }}, playerCount: count + 1};
    delete next.offlineSinceAt;
    return next;
  });
  if (failure) throw failure;
  if (!result.committed) throw new ServiceError('unavailable', 'Odaya katılınamadı. Tekrar deneyin.');
  // Only a verified member receives the internal ID and can read the room.
  return {roomId};
}
