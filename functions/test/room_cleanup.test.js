import {test} from 'node:test';
import assert from 'node:assert/strict';
import {cleanupEmptyRoom, cleanupOfflineRooms, leaveRoom, OFFLINE_ROOM_MS} from '../src/room_cleanup.js';

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

test('last disconnect starts a one-hour grace period, preserving backgrounded players and scores', async () => {
  const ref = reference({players: {host: {isOnline: false}, guest: {isOnline: false}}, questions: ['kept only while occupied']});
  assert.equal((await cleanupEmptyRoom(ref, 1000)).committed, true);
  assert.equal(ref.room.offlineSinceAt, 1000);
  assert.equal((await cleanupEmptyRoom(ref, 2000)).committed, false);
  assert.equal((await cleanupEmptyRoom(ref, 1000 + OFFLINE_ROOM_MS - 1)).committed, false);
  assert.equal(ref.room.offlineSinceAt, 1000);
  assert.equal((await cleanupEmptyRoom(ref, 1000 + OFFLINE_ROOM_MS)).committed, true);
  assert.equal(ref.room, null);
  assert.equal(ref.listeners.size, 0);
});

test('returning from background clears the previous offline deadline', async () => {
  const ref = reference({players: {host: {isOnline: true}}, offlineSinceAt: 1000});
  await cleanupEmptyRoom(ref, 2000);
  assert.equal(ref.room.offlineSinceAt, undefined);
  ref.room.players.host.isOnline = false;
  await cleanupEmptyRoom(ref, 3000);
  assert.equal(ref.room.offlineSinceAt, 3000);
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

test('explicit host leave transfers ownership and keeps the remaining player and game intact', async () => {
  const room = {hostId:'host', playerCount:2, status:'playing', questions:['q'],
    players:{host:{isOnline:true,isHost:true}, guest:{isOnline:true,isHost:false}}, progress:{guest:{score:400}}};
  const ref = reference(room);
  await leaveRoom({ref:() => ref}, 'host', {roomId:'abc234'}, 1000);
  assert.equal(ref.room.playerCount, 1);
  assert.equal(ref.room.hostId, 'guest');
  assert.equal(ref.room.players.guest.isHost, true);
  assert.equal(ref.room.players.host, undefined);
  assert.deepEqual(ref.room.progress, room.progress);
  assert.deepEqual(ref.room.questions, room.questions);
  assert.equal(room.players.host.isHost, true); // No mutation of the transaction input.
  assert.equal(ref.listeners.size, 0);
});

test('only the last explicit leave deletes immediately, without waiting an hour', async () => {
  const ref = reference({hostId:'host', playerCount:2,
    players:{host:{isOnline:true,isHost:true}, guest:{isOnline:true,isHost:false}}});
  const database = {ref:() => ref};
  await leaveRoom(database, 'guest', {roomId:'abc234'}, 1000);
  assert.equal(ref.room.playerCount, 1);
  assert.equal(ref.room.hostId, 'host');
  await leaveRoom(database, 'host', {roomId:'abc234'}, 1001);
  assert.equal(ref.room, null);
  assert.equal((await leaveRoom(database, 'host', {roomId:'abc234'})).committed, false);
});

test('leaving while other members are offline keeps their membership for one hour', async () => {
  const ref = reference({hostId:'host', playerCount:2,
    players:{host:{isOnline:true,isHost:true}, guest:{isOnline:false,isHost:false}}});
  await leaveRoom({ref:() => ref}, 'host', {roomId:'abc234'}, 1000);
  assert.equal(ref.room.players.guest.isHost, true);
  assert.equal(ref.room.offlineSinceAt, 1000);
  await leaveRoom({ref:() => ref}, 'guest', {roomId:'abc234'}, 1001);
  assert.equal(ref.room, null);
});

test('concurrent last-player departures retry against the latest membership', async () => {
  const ref = reference({hostId:'host', players:{host:{isOnline:true}, guest:{isOnline:true}}},
    {hostId:'guest', playerCount:1, players:{guest:{isOnline:true,isHost:true}}});
  await leaveRoom({ref:() => ref}, 'guest', {roomId:'abc234'});
  assert.equal(ref.room, null);
});

test('unauthenticated, malformed and nonmember leave requests cannot change rooms', async () => {
  const ref = reference({players:{host:{isOnline:true}}});
  const database = {ref:() => ref};
  await assert.rejects(leaveRoom(database, '', {roomId:'abc234'}), e => e.code === 'unauthenticated');
  await assert.rejects(leaveRoom(database, 'host', {roomId:'../abc234'}), e => e.code === 'invalid-argument');
  const original = structuredClone(ref.room);
  assert.equal((await leaveRoom(database, 'outsider', {roomId:'abc234'})).committed, false);
  assert.deepEqual(ref.room, original);
});

test('scheduled cleanup uses the offline index and protects a reconnect after the query', async () => {
  const now = OFFLINE_ROOM_MS + 1000;
  const old = reference({players:{host:{isOnline:false}},offlineSinceAt:1000});
  const returned = reference({players:{guest:{isOnline:true}},offlineSinceAt:1000});
  const query = {
    orderByChild(key) {assert.equal(key,'offlineSinceAt');return this;},
    startAt(value) {assert.equal(value,1);return this;},
    endAt(value) {assert.equal(value,1000);return this;},
    limitToFirst(value) {assert.equal(value,100);return this;},
    async get() {return {val:() => ({old:{},returned:{}})};},
  };
  await cleanupOfflineRooms({ref:path => path === 'rooms' ? query : path === 'rooms/old' ? old : returned}, now);
  assert.equal(old.room, null);
  assert.equal(returned.room.players.guest.isOnline, true);
  assert.equal(returned.room.offlineSinceAt, undefined);
});
