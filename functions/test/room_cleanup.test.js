import {test} from 'node:test';
import assert from 'node:assert/strict';
import {cleanupEmptyRoom} from '../src/room_cleanup.js';

function reference(room, latest) {
  return {
    room, listeners: new Set(),
    on(_event, listener) {this.listeners.add(listener);queueMicrotask(listener);},
    off(_event, listener) {this.listeners.delete(listener);},
    async transaction(update) {
      if (latest) {
        update(this.room); // First snapshot loses a race to a reconnect/join.
        this.room = latest;
      }
      const next = update(this.room);
      if (next !== undefined) this.room = next;
      return {committed: next !== undefined};
    },
  };
}

test('last disconnect deletes the empty room and releases its transaction listener', async () => {
  const ref = reference({players: {host: {isOnline: false}, guest: {isOnline: false}}, questions: ['kept only while occupied']});
  assert.equal((await cleanupEmptyRoom(ref)).committed, true);
  assert.equal(ref.room, null);
  assert.equal(ref.listeners.size, 0);
});

test('one online player preserves the whole room when others disconnect or leave', async () => {
  const room = {players: {host: {isOnline: false}, guest: {isOnline: true}}, progress: {guest: {score: 500}}};
  const ref = reference(room);
  assert.equal((await cleanupEmptyRoom(ref)).committed, false);
  assert.deepEqual(ref.room, room);
  assert.equal(ref.listeners.size, 0);
});

test('reconnect or join during cleanup aborts deletion against the latest snapshot', async () => {
  const online = {players: {host: {isOnline: true}}};
  const ref = reference({players: {host: {isOnline: false}}}, online);
  assert.equal((await cleanupEmptyRoom(ref)).committed, false);
  assert.deepEqual(ref.room, online);
});

test('delayed events and repeated cleanup never recreate an already deleted room', async () => {
  const ref = reference(null);
  assert.equal((await cleanupEmptyRoom(ref)).committed, false);
  assert.equal((await cleanupEmptyRoom(ref)).committed, false);
  assert.equal(ref.room, null);
});

test('a room with no remaining players is removed', async () => {
  const ref = reference({status: 'lobby', playerCount: 0});
  assert.equal((await cleanupEmptyRoom(ref)).committed, true);
  assert.equal(ref.room, null);
});

test('transaction failure still releases the temporary server listener', async () => {
  const ref = reference({players: {}});
  ref.transaction = async () => {throw new Error('unavailable');};
  await assert.rejects(cleanupEmptyRoom(ref), /unavailable/);
  assert.equal(ref.listeners.size, 0);
});
