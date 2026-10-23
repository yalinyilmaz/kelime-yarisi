import {test} from 'node:test';
import assert from 'node:assert/strict';
import {listRooms, joinListedRoom} from '../src/room_directory.js';

const directoryId = '81d74481-52e7-4478-a66c-5668ec5d21fa';
const lobby = (extra = {}) => ({
  name: 'Akşam Yarışı', code: 'ABC-234', hostId: 'host', targetPlayerCount: 3,
  playerCount: 1, status: 'lobby', directoryId, visibility: 'private',
  players: {host: {displayName: 'Yalın', isHost: true, isReady: true, isOnline: true}},
  ...extra,
});
function database(initial) {
  const db = {rooms: structuredClone(initial), beforeTransaction: undefined};
  db.ref = path => {
    let order, equal, limit;
    const id = path.split('/')[1];
    const ref = {
      on(_event, listener) {queueMicrotask(listener);}, off() {},
      orderByChild(value) {order = value;return this;},
      equalTo(value) {equal = value;return this;},
      limitToFirst(value) {limit = value;return this;},
      async get() {
        assert.equal(path, 'rooms');
        return {val: () => Object.fromEntries(Object.entries(db.rooms)
          .filter(([, room]) => room[order] === equal).slice(0, limit))};
      },
      async transaction(update) {
        if (db.beforeTransaction) {
          update(structuredClone(db.rooms[id]));
          db.beforeTransaction(db.rooms[id]);
          db.beforeTransaction = undefined;
        }
        const result = update(structuredClone(db.rooms[id] ?? null));
        if (result !== undefined) db.rooms[id] = result;
        return {committed: result !== undefined, snapshot: {val: () => db.rooms[id] ?? null}};
      },
    };
    return ref;
  };
  return db;
}
const request = extra => ({directoryId, displayName: 'Misafir', ...extra});

test('directory hides codes, internal IDs, membership and game data, includes locked and public rooms', async () => {
  const db = database({abc234: lobby({questions: [{answer: 'GİZLİ'}]}), def345: lobby({directoryId: '91d74481-52e7-4478-a66c-5668ec5d21fa', visibility: 'public'}),
    closed: lobby({status: 'playing'}), offline: lobby({players: {host: {isOnline: false}}})});
  const {rooms} = await listRooms(db, 'viewer');
  assert.equal(rooms.length, 2);
  assert.deepEqual(rooms[0], {id: directoryId, name: 'Akşam Yarışı', visibility: 'private', playerCount: 1, capacity: 3});
  const output = JSON.stringify(rooms);
  for (const secret of ['ABC-234', 'abc234', 'host', 'GİZLİ', 'questions']) assert.ok(!output.includes(secret));
});

test('legacy rooms default private and receive stable opaque handles without changing invite codes', async () => {
  const db = database({abc234: lobby({directoryId: undefined, visibility: undefined})});
  const first = await listRooms(db, 'viewer');
  const second = await listRooms(db, 'viewer');
  assert.match(first.rooms[0].id, /^[0-9a-f-]{36}$/);
  assert.deepEqual(second, first);
  assert.equal(first.rooms[0].visibility, 'private');
  assert.equal(db.rooms.abc234.code, 'ABC-234');
});

test('a room deleted or started while getting a handle is never recreated or listed', async () => {
  const db = database({abc234: lobby({directoryId: undefined})});
  db.beforeTransaction = room => {room.status = 'playing';};
  assert.deepEqual(await listRooms(db, 'viewer'), {rooms: []});
});

test('public entry needs no code, updates actual membership, preserves scores and clears offline marker', async () => {
  const db = database({abc234: lobby({visibility: 'public', offlineSinceAt: 1, playerCount: 99, progress: {host: {score: 400}}})});
  assert.deepEqual(await joinListedRoom(db, 'guest', request(), 1000), {roomId: 'abc234'});
  assert.equal(db.rooms.abc234.playerCount, 2);
  assert.deepEqual(db.rooms.abc234.players.guest, {displayName: 'Misafir', isHost: false, isReady: false, isOnline: true, lastSeenAt: 1000});
  assert.equal(db.rooms.abc234.progress.host.score, 400);
  assert.equal(db.rooms.abc234.offlineSinceAt, undefined);
});

test('private entry requires the selected room code; another code cannot join that room', async () => {
  const db = database({abc234: lobby()});
  for (const roomCode of [undefined, 'DEF-345', '']) {
    await assert.rejects(joinListedRoom(db, 'guest', request({roomCode})), error => error.code === 'permission-denied');
  }
  assert.equal(db.rooms.abc234.playerCount, 1);
  await joinListedRoom(db, 'guest', request({roomCode: 'abc 234'}));
  assert.equal(db.rooms.abc234.playerCount, 2);
});

test('retrying an existing membership never resets host/readiness or increments count', async () => {
  const original = lobby();
  const db = database({abc234: original});
  await joinListedRoom(db, 'host', request());
  await joinListedRoom(db, 'host', request());
  assert.deepEqual(db.rooms.abc234, original);
});

test('full, closed and missing rooms reject without adding members', async () => {
  for (const [extra, code] of [[{targetPlayerCount: 1}, 'resource-exhausted'], [{status: 'playing'}, 'failed-precondition']]) {
    const db = database({abc234: lobby({visibility: 'public', ...extra})});
    await assert.rejects(joinListedRoom(db, 'guest', request()), error => error.code === code);
    assert.equal(db.rooms.abc234.players.guest, undefined);
  }
  await assert.rejects(joinListedRoom(database({}), 'guest', request()), error => error.code === 'not-found');
});

test('join transaction rechecks capacity and game start after a competing operation', async () => {
  for (const [mutate, code] of [
    [room => {room.status = 'countdown';}, 'failed-precondition'],
    [room => {room.targetPlayerCount = 2; room.players.other = {isOnline: true};}, 'resource-exhausted'],
  ]) {
    const db = database({abc234: lobby({visibility: 'public'})});
    db.beforeTransaction = mutate;
    await assert.rejects(joinListedRoom(db, 'guest', request()), error => error.code === code);
    assert.equal(db.rooms.abc234.players.guest, undefined);
  }
});

test('unauthenticated or malformed requests cannot list or change rooms', async () => {
  const db = database({abc234: lobby()});
  await assert.rejects(listRooms(db, ''), error => error.code === 'unauthenticated');
  await assert.rejects(joinListedRoom(db, '', request()), error => error.code === 'unauthenticated');
  for (const invalid of [{directoryId: 'abc234'}, {displayName: ''}, {displayName: 'x'.repeat(25)}]) {
    await assert.rejects(joinListedRoom(db, 'guest', request(invalid)), error => error.code === 'invalid-argument');
  }
});
