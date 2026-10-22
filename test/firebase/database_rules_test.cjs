// Emulator only. Dependencies: @firebase/rules-unit-testing and firebase.
const fs = require('node:fs');
const path = require('node:path');
const {assertFails, assertSucceeds, initializeTestEnvironment} = require('@firebase/rules-unit-testing');
const {get, increment, ref, runTransaction, serverTimestamp, set, update} = require('firebase/database');
const {setLogLevel} = require('firebase/app');
setLogLevel('silent');
let checks = 0;
async function succeeds(action) {await assertSucceeds(action); checks++;}
async function fails(action) {await assertFails(action); checks++;}
const player = (displayName, isHost = false) => ({displayName, isHost, isReady: true, isOnline: true, lastSeenAt: Date.now()});
const progress = (overrides = {}) => ({questionIndex: 1, score: 400, correctCount: 1, wrongCount: 0,
  finished: false, lastOutcome: 'correct', updatedAtMs: serverTimestamp(), ...overrides});
const hint = (revealedCount, firstVoterId, questionIndex = 0) => ({questionIndex, revealedCount, ...(firstVoterId ? {firstVoterId} : {})});

async function main() {
  const env = await initializeTestEnvironment({projectId: 'demo-kelime-yarisi', database: {
    host: '127.0.0.1', port: 9000, rules: fs.readFileSync(path.resolve(__dirname, '../../database.rules.json'), 'utf8'),
  }});
  const db = (uid) => env.authenticatedContext(uid).database();
  const host = db('host'), guest = db('guest'), outsider = db('outsider');
  const adminUpdate = (roomPath, values) => env.withSecurityRulesDisabled((context) => update(ref(context.database(), roomPath), values));
  try {
    await env.clearDatabase();
    for (let count = 2; count <= 6; count++) {
      const roomPath = `rooms/abc23${count}`;
      const code = `ABC-23${count}`;
      await succeeds(set(ref(host, roomPath), {name: 'Test Odası', code, hostId: 'host', targetPlayerCount: count,
        playerCount: 1, gameMode: 'quick', status: 'lobby', createdAt: Date.now(), players: {host: player('Host', true)}}));
      await fails(get(ref(outsider, roomPath)));
      await succeeds(update(ref(guest, roomPath), {'players/guest': player('Guest'), playerCount: increment(1)}));
      for (let i = 2; i < count; i++) {
        await succeeds(update(ref(db(`p${i}`), roomPath), {[`players/p${i}`]: player(`Oyuncu ${i}`), playerCount: increment(1)}));
      }
      await fails(update(ref(outsider, roomPath), {'players/outsider': player('Outsider'), playerCount: increment(1)}));
      const h = ref(host, `${roomPath}/hints/0`), g = ref(guest, `${roomPath}/hints/0`);
      const p = ref(guest, `${roomPath}/progress/guest`);
      await fails(set(h, hint(1)));
      await fails(set(p, progress()));
      await fails(update(ref(host, roomPath), {status: 'countdown', startsAtMs: Date.now() + 4000, questionSetId: 'quick-v1'}));
      await succeeds(update(ref(host, roomPath), {status: 'countdown', startsAtMs: Date.now() + 4000,
        questionSetId: 'quick-v1', gameplayVersion: 'sync-v1'}));
      await fails(set(h, hint(1)));
      await fails(set(ref(host, `${roomPath}/status`), 'playing'));
      await adminUpdate(roomPath, {startsAtMs: Date.now() - 1000});
      await succeeds(set(ref(host, `${roomPath}/status`), 'playing'));
      await fails(set(ref(host, `${roomPath}/status`), 'results'));
      await fails(set(ref(outsider, `${roomPath}/hints/0`), hint(1)));
      await fails(set(ref(guest, `${roomPath}/hints/1`), hint(1, null, 1)));
      await fails(set(ref(guest, `${roomPath}/hints/0`), hint(1, null, 1)));
      await fails(set(h, hint(2)));
      if (count <= 3) {
        await succeeds(set(h, hint(1)));
      } else {
        await fails(set(h, hint(1)));
        await fails(set(h, hint(0, 'guest')));
        await succeeds(set(h, hint(0, 'host')));
        await fails(set(h, hint(1)));
        await fails(set(h, hint(0, 'host')));
        await fails(set(g, hint(0, 'guest')));
        await fails(set(g, hint(0)));
        await succeeds(set(g, hint(1)));
      }
      await succeeds(get(g));
      const shared = (await get(g)).val();
      if (shared.revealedCount !== 1 || shared.firstVoterId) throw Error('Shared reveal/vote reset failed');
      checks++;
      await fails(set(h, hint(0)));
      await fails(set(h, null));
      await fails(set(p, progress())); // shared hint lowered the value to 300
      await fails(set(p, progress({score: 9999})));
      await fails(set(ref(host, `${roomPath}/progress/guest`), progress({score: 300})));
      await fails(set(p, progress({score: 300, lastOutcome: 'timeout', correctCount: 0, wrongCount: 1})));
      await succeeds(set(p, progress({score: 300})));
      await fails(set(g, count <= 3 ? hint(2) : hint(1, 'guest'))); // answered players cannot vote
      await fails(set(p, progress({score: 200})));
      await fails(set(p, null));
      await fails(set(p, progress({questionIndex: 2, correctCount: 2, score: 800})));
      const hintFromHost = (revealedCount) => count <= 3 ? hint(revealedCount + 1) : hint(revealedCount, 'host');
      const other = count <= 3 ? guest : db('p2');
      for (let step = 1; step < 3; step++) {
        await succeeds(set(h, hintFromHost(step)));
        if (count >= 4) await succeeds(set(ref(other, `${roomPath}/hints/0`), hint(step + 1)));
      }
      await fails(set(h, hintFromHost(3))); // final letter stays hidden
      await adminUpdate(roomPath, {startsAtMs: Date.now() - 26000});
      await fails(set(h, hint(3, 'host')));
      await fails(set(ref(host, `${roomPath}/progress/host`), progress({score: 100})));
      await fails(set(ref(host, `${roomPath}/progress/host`), progress({score: -100, correctCount: 0, wrongCount: 1, lastOutcome: 'timeout'})));
      await succeeds(set(ref(host, `${roomPath}/progress/host`), progress({score: 0, correctCount: 0, wrongCount: 1, lastOutcome: 'timeout'})));
      await succeeds(set(p, progress({questionIndex: 2, score: 800, correctCount: 2})));
      await fails(set(p, progress({questionIndex: 3, score: 1400, correctCount: 3})));
      await adminUpdate(roomPath, {startsAtMs: Date.now() - 176000});
      await succeeds(set(ref(guest, `${roomPath}/status`), 'results'));
      await fails(set(ref(host, `${roomPath}/hints/1`), hint(1, null, 1)));
      const score = 800;
      for (let i = 2; i < 7; i++) {
        await succeeds(set(p, progress({questionIndex: i + 1, score, correctCount: 2, wrongCount: i - 1,
          lastOutcome: 'timeout', finished: i === 6})));
      }
      await fails(set(p, progress({questionIndex: 7, score: 0, correctCount: 2, wrongCount: 5, lastOutcome: 'timeout', finished: true})));
      await fails(set(p, null));
      await succeeds(set(ref(host, roomPath), null));
    }

    // Wrong speech cannot gain or subtract points, or write another player's progress.
    const wrongPath = 'rooms/err234';
    await env.withSecurityRulesDisabled(context => set(ref(context.database(), wrongPath), {
      name:'Wrong Test', code:'ERR-234', hostId:'host', targetPlayerCount:2, playerCount:2,
      gameMode:'classic', status:'playing', questionSetId:'classic-v1', gameplayVersion:'sync-v1',
      startsAtMs:Date.now()-1000, createdAt:Date.now(), players:{host:player('Host',true),guest:player('Guest')},
    }));
    const wrong = score => progress({score, correctCount:0, wrongCount:1, lastOutcome:'wrong'});
    await fails(set(ref(guest, `${wrongPath}/progress/guest`), wrong(-400)));
    await fails(set(ref(guest, `${wrongPath}/progress/guest`), wrong(400)));
    await fails(set(ref(host, `${wrongPath}/progress/guest`), wrong(0)));
    await succeeds(set(ref(guest, `${wrongPath}/progress/guest`), wrong(0)));
    await fails(set(ref(guest, `${wrongPath}/progress/guest`), wrong(400)));

    // Concurrent requests complete a pair once; a retry cannot open the next letter.
    const roomPath = 'rooms/xyz678';
    await env.withSecurityRulesDisabled((context) => set(ref(context.database(), roomPath), {
      name: 'Race Test', code: 'XYZ-678', hostId: 'host', targetPlayerCount: 4, playerCount: 4,
      gameMode: 'quick', status: 'playing', questionSetId: 'quick-v1', gameplayVersion: 'sync-v1',
      startsAtMs: Date.now() - 1000, createdAt: Date.now(),
      players: {host: player('Host', true), guest: player('Guest'), p2: player('Player 2'), p3: player('Player 3')},
    }));
    async function vote(database, uid, expected) {
      const target = ref(database, `${roomPath}/hints/0`);
      const snapshot = await get(target);
      return runTransaction(target, (value) => {
        const current = value || snapshot.val() || {questionIndex: 0, revealedCount: 0};
        if (current.revealedCount !== expected || current.firstVoterId === uid) return;
        return current.firstVoterId ? hint(current.revealedCount + 1) : hint(current.revealedCount, uid);
      }, {applyLocally: false});
    }
    await Promise.all([vote(host, 'host', 0), vote(guest, 'guest', 0), vote(db('p2'), 'p2', 0)]);
    const shared = (await get(ref(host, `${roomPath}/hints/0`))).val();
    if (shared.revealedCount !== 1 || shared.firstVoterId) throw Error('Concurrent votes opened extra letters');
    checks++;
    await vote(host, 'host', 1);
    const duplicate = await vote(host, 'host', 1);
    if (duplicate.committed) throw Error('Duplicate vote committed');
    checks++;
    await vote(guest, 'guest', 1);
    if ((await get(ref(host, `${roomPath}/hints/0`))).val().revealedCount !== 2) throw Error('New reveal did not reset voters');
    checks++;

    // Every classic question has its own deadline and exact value; final results wait for 350 seconds.
    await adminUpdate(roomPath, {gameMode: 'classic', questionSetId: 'classic-v1', hints: null, progress: null});
    let score = 0;
    for (let i = 0; i < 14; i++) {
      await adminUpdate(roomPath, {startsAtMs: Date.now() - i * 25000 - 1000});
      score += (4 + Math.floor(i / 2)) * 100;
      await succeeds(set(ref(guest, `${roomPath}/progress/guest`), progress({questionIndex: i + 1, correctCount: i + 1,
        score, finished: i === 13})));
    }
    await fails(set(ref(host, `${roomPath}/status`), 'results'));
    await adminUpdate(roomPath, {startsAtMs: Date.now() - 351000});
    await succeeds(set(ref(guest, `${roomPath}/status`), 'results'));
    await fails(set(ref(outsider, `${roomPath}/status`), 'results'));
    await succeeds(update(ref(guest, roomPath), {'players/guest': null, playerCount: increment(-1)}));
    await fails(get(ref(guest, roomPath)));
    await succeeds(set(ref(host, roomPath), null));
    console.log(`${checks} synchronized game security checks passed.`);
  } finally {await env.cleanup();}
}
main().catch((error) => {console.error(error); process.exitCode = 1;});
