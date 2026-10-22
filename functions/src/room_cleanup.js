import {transaction} from './database_transaction.js';

// Re-read inside a transaction: a delayed disconnect event must never delete a
// room that another player has joined or reconnected to in the meantime.
export async function cleanupEmptyRoom(roomRef) {
  return transaction(roomRef, room => {
    if (!room || Object.values(room.players ?? {}).some(p => p?.isOnline === true)) {
      return undefined;
    }
    return null;
  });
}
