// Run against the Realtime Database emulator only.
// Dependencies: @firebase/rules-unit-testing and firebase (NODE_PATH may point to a temporary install).
const fs = require('node:fs');
const path = require('node:path');
const {assertFails, assertSucceeds, initializeTestEnvironment} = require('@firebase/rules-unit-testing');
const {get, increment, ref, serverTimestamp, set, update} = require('firebase/database');

const projectId = 'demo-kelime-yarisi';
const roomPath = 'rooms/abc234';
const player = (displayName, isHost = false) => ({displayName, isHost, isReady: true, isOnline: true, lastSeenAt: Date.now()});
const progress = (overrides = {}) => ({questionIndex: 0, score: 0, revealedMask: 0, correctCount: 0, wrongCount: 0,
  finished: false, updatedAtMs: serverTimestamp(), ...overrides});
let checks = 0;
async function succeeds(action) {await assertSucceeds(action); checks++;}
async function fails(action) {await assertFails(action); checks++;}

async function main() {
  const env = await initializeTestEnvironment({projectId, database: {
    host: '127.0.0.1', port: 9000,
    rules: fs.readFileSync(path.resolve(__dirname, '../../database.rules.json'), 'utf8'),
  }});
  const host = env.authenticatedContext('host').database();
  const guest = env.authenticatedContext('guest').database();
  const outsider = env.authenticatedContext('outsider').database();
  const anonymous = env.unauthenticatedContext().database();
  const guestProgress = ref(guest, `${roomPath}/progress/guest`);
  const adminUpdate = (values) => env.withSecurityRulesDisabled((context) => update(ref(context.database(), roomPath), values));
  try {
    await env.clearDatabase();
    await succeeds(set(ref(host, roomPath), {
      name: 'Test Odası', code: 'ABC-234', hostId: 'host', targetPlayerCount: 2, playerCount: 1,
      gameMode: 'quick', status: 'lobby', createdAt: Date.now(), players: {host: player('Host', true)},
    }));
    await fails(get(ref(outsider, roomPath)));
    await fails(get(ref(anonymous, roomPath)));
    await succeeds(update(ref(guest, roomPath), {'players/guest': player('Guest'), playerCount: increment(1)}));
    await succeeds(get(ref(guest, roomPath)));
    await fails(set(guestProgress, progress({revealedMask: 1})));
    await fails(update(ref(host, roomPath), {startsAtMs: Date.now() + 4000, status: 'countdown', questionSetId: 'classic-v1'}));
    await succeeds(update(ref(host, roomPath), {startsAtMs: Date.now() + 4000, status: 'countdown', questionSetId: 'quick-v1'}));
    await fails(set(ref(host, `${roomPath}/status`), 'playing'));
    await fails(set(guestProgress, progress({revealedMask: 1})));
    await fails(set(ref(guest, `${roomPath}/questionSetId`), 'classic-v1'));
    await adminUpdate({startsAtMs: Date.now() - 1000});
    await fails(set(ref(guest, `${roomPath}/status`), 'playing'));
    await succeeds(set(ref(host, `${roomPath}/status`), 'playing'));
    await fails(set(ref(host, `${roomPath}/status`), 'results'));
    await fails(set(ref(guest, `${roomPath}/status`), 'results'));
    await fails(set(ref(outsider, `${roomPath}/progress/outsider`), progress()));
    await fails(set(ref(host, `${roomPath}/progress/guest`), progress()));
    await fails(set(guestProgress, progress({questionIndex: 2, correctCount: 2, score: 800})));
    await fails(set(guestProgress, progress({questionIndex: 1, correctCount: 1, score: 0})));
    await succeeds(set(guestProgress, progress({revealedMask: 1})));
    await fails(set(guestProgress, progress({revealedMask: 1, score: 100})));
    await fails(set(guestProgress, progress({revealedMask: 0})));
    await fails(set(guestProgress, progress({revealedMask: 1.5})));
    await fails(set(guestProgress, progress({revealedMask: 2048})));
    await fails(set(guestProgress, progress({revealedMask: 3, injected: true})));
    await fails(set(guestProgress, null));
    await succeeds(set(guestProgress, progress({revealedMask: 3})));
    await succeeds(set(guestProgress, progress({questionIndex: 1, correctCount: 1, score: 200})));
    await succeeds(set(ref(host, `${roomPath}/progress/host`), progress({questionIndex: 1, wrongCount: 1, score: -400})));
    await fails(set(guestProgress, progress({questionIndex: 1, correctCount: 1, score: 980000})));
    await fails(set(guestProgress, progress({questionIndex: 1, correctCount: 1, score: 200, finished: true})));
    await fails(set(guestProgress, progress({questionIndex: 0})));
    await succeeds(set(guestProgress, progress({questionIndex: 2, correctCount: 1, wrongCount: 1, score: -300})));
    await succeeds(set(guestProgress, progress({questionIndex: 2, correctCount: 1, wrongCount: 1, score: -300, revealedMask: 1})));
    const snapshot = await get(ref(host, `${roomPath}/progress/host`));
    if (snapshot.val().score !== -400 || snapshot.val().revealedMask !== 0) throw Error('Guest progress affected host');
    checks++;
    await adminUpdate({startsAtMs: Date.now() - 121000});
    await fails(set(guestProgress, progress({questionIndex: 2, correctCount: 1, wrongCount: 1, score: -300, revealedMask: 3})));
    await fails(set(guestProgress, progress({questionIndex: 3, correctCount: 2, wrongCount: 1, score: 200, finished: true})));
    await succeeds(set(ref(guest, `${roomPath}/status`), 'results'));
    await succeeds(set(guestProgress, progress({questionIndex: 3, correctCount: 1, wrongCount: 2, score: -800, finished: true})));
    await fails(set(guestProgress, progress({questionIndex: 4, correctCount: 2, wrongCount: 2, score: -100, finished: true})));
    await fails(set(guestProgress, null));
    await succeeds(set(ref(host, `${roomPath}/progress/host`), progress({questionIndex: 2, wrongCount: 2, score: -800, finished: true})));
    await succeeds(set(ref(host, `${roomPath}/status`), 'results'));
    await fails(set(ref(outsider, `${roomPath}/status`), 'results'));

    // Full quick game, finishing early and freezing the final result.
    await adminUpdate({status: 'playing', startsAtMs: Date.now() - 1000, progress: null});
    let score = 0;
    for (let i = 0; i < 7; i++) {
      score += (i + 4) * 100;
      await succeeds(set(guestProgress, progress({questionIndex: i + 1, correctCount: i + 1, score, finished: i === 6})));
    }
    await fails(set(ref(host, `${roomPath}/status`), 'results'));
    await fails(set(guestProgress, progress({questionIndex: 7, correctCount: 7, score: 5000, finished: true})));

    // Classic has a four minute deadline; a player who did nothing still gets one timeout penalty.
    await adminUpdate({gameMode: 'classic', questionSetId: 'classic-v1', startsAtMs: Date.now() - 121000, progress: null});
    await fails(set(ref(host, `${roomPath}/status`), 'results'));
    await succeeds(set(guestProgress, progress({questionIndex: 1, correctCount: 1, score: 400})));
    await adminUpdate({startsAtMs: Date.now() - 241000, progress: null});
    await succeeds(set(ref(guest, `${roomPath}/status`), 'results'));
    await succeeds(set(guestProgress, progress({questionIndex: 1, wrongCount: 1, score: -400, finished: true})));
    await fails(set(guestProgress, progress({questionIndex: 1, wrongCount: 1, score: -300, finished: true})));
    await adminUpdate({status: 'playing', startsAtMs: Date.now() - 1000, progress: null});
    score = 0;
    for (let i = 0; i < 14; i++) {
      score += (4 + Math.floor(i / 2)) * 100;
      await succeeds(set(guestProgress, progress({questionIndex: i + 1, correctCount: i + 1, score, finished: i === 13})));
    }
    await fails(set(guestProgress, progress({questionIndex: 14, correctCount: 14, score: 9900, finished: true})));
    await succeeds(update(ref(guest, roomPath), {'players/guest': null, playerCount: increment(-1)}));
    await fails(get(ref(guest, roomPath)));
    await fails(set(guestProgress, progress()));
    await succeeds(set(ref(host, roomPath), null));
    console.log(`${checks} Realtime Database security checks passed.`);
  } finally {await env.cleanup();}
}
main().catch((error) => {console.error(error); process.exitCode = 1;});
