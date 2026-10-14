import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/data/question_bank.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/domain/shared_hints.dart';
import 'package:kelime_yarisi/features/game/presentation/audio/game_sound_controller.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_state.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';

import 'game_cubit_test.dart' show testRoom;

class FakeEffectPlayer extends Fake implements AudioPlayer {
  int plays = 0;
  int stops = 0;
  int disposals = 0;
  bool failLoading = false;
  Future<void>? stopBarrier;
  @override
  Future<void> setAudioContext(AudioContext context) async {}
  @override
  Future<void> setPlayerMode(PlayerMode mode) async {}
  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setSourceAsset(String path, {String? mimeType}) async {
    if (failLoading) throw StateError('backend unavailable');
  }

  @override
  Future<void> resume() async {
    plays++;
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopBarrier;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

GameState soundState({
  int seconds = 15,
  int revealed = 0,
  String? voter,
  bool connected = true,
  bool leaving = false,
  int questionIndex = 0,
  RoomStatus status = RoomStatus.playing,
}) => GameState(
  room: testRoom(
    playerCount: 4,
    hints: {
      questionIndex: SharedHints(revealedCount: revealed, firstVoterId: voter),
    },
  ).copyWith(status: status),
  questions: QuestionBank.forSet('quick-v1'),
  progress: const GameProgress(),
  clockReady: true,
  isConnected: connected,
  isLeaving: leaving,
  serverNowMs: 1000 + (questionIndex + 1) * 25000 - seconds * 1000,
);

void main() {
  late FakeEffectPlayer hint;
  late FakeEffectPlayer tick;
  late GameSoundController sounds;
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  setUp(() async {
    hint = FakeEffectPlayer();
    tick = FakeEffectPlayer();
    sounds = GameSoundController(hintPlayer: hint, tickPlayer: tick);
    await sounds.initialize();
  });
  tearDown(() => sounds.dispose());

  test('An in-flight sound is cancelled when results arrive before playback starts', () async {
    final pending = Completer<void>();
    hint.stopBarrier = pending.future;
    sounds.update(soundState());
    sounds.update(soundState(revealed: 1));
    sounds.update(soundState(revealed: 1, status: RoomStatus.results));
    pending.complete();
    await flush();
    expect(hint.plays, 0);
  });

  test('An uncompleted vote is silent; shared letters sound once without replaying snapshots', () async {
    sounds.update(soundState());
    sounds.update(soundState(voter: 'guest'));
    await flush();
    expect(hint.plays, 0);
    sounds.update(soundState(revealed: 1));
    sounds.update(soundState(revealed: 1));
    await flush();
    expect(hint.plays, 1);
    sounds.update(
      soundState(revealed: 0),
    ); // Stale event must not replay a sound.
    sounds.update(soundState(revealed: 1));
    await flush();
    expect(hint.plays, 1);
    sounds.update(soundState(revealed: 2));
    await flush();
    expect(hint.plays, 2);
  });

  test('Last five seconds tick once each, including clock corrections and a new question', () async {
    sounds.update(soundState(seconds: 6));
    for (var s = 5; s >= 1; s--) {
      sounds.update(soundState(seconds: s));
      sounds.update(soundState(seconds: s));
      await flush();
    }
    expect(tick.plays, 5);
    sounds.update(soundState(seconds: 6));
    sounds.update(soundState(seconds: 5));
    await flush();
    expect(tick.plays, 5);
    sounds.update(soundState(questionIndex: 1, seconds: 6));
    sounds.update(soundState(questionIndex: 1, seconds: 5));
    await flush();
    expect(tick.plays, 6);
  });

  test('Mute suppresses cues, stops audio, and unmuting does not replay old letters', () async {
    sounds.update(soundState(seconds: 6));
    await sounds.setEnabled(false);
    sounds.update(soundState(seconds: 5, revealed: 1));
    await flush();
    expect(hint.plays + tick.plays, 0);
    expect(hint.stops, greaterThan(0));
    await sounds.setEnabled(true);
    sounds.update(soundState(seconds: 5, revealed: 1));
    await flush();
    expect(hint.plays + tick.plays, 0);
    sounds.update(soundState(seconds: 4, revealed: 2));
    await flush();
    expect(hint.plays, 1);
    expect(tick.plays, 1);
  });

  test('Background and reconnect skip historic reveals; closing/results are silent', () async {
    sounds.update(soundState(seconds: 6));
    await sounds.setForeground(false);
    sounds.update(soundState(seconds: 5, revealed: 1));
    await sounds.setForeground(true);
    sounds.update(soundState(seconds: 4, revealed: 2));
    await flush();
    expect(hint.plays + tick.plays, 0);
    sounds.update(soundState(seconds: 3, revealed: 2, connected: false));
    sounds.update(soundState(seconds: 3, revealed: 3));
    await flush();
    expect(hint.plays, 0);
    sounds.update(soundState(seconds: 2, leaving: true));
    sounds.update(soundState(seconds: 1, status: RoomStatus.results));
    await flush();
    expect(tick.plays, 1);
  });

  test(
    'Audio loading failure and disposal never interrupt game updates',
    () async {
      await sounds.dispose();
      expect(hint.disposals, 1);
      expect(tick.disposals, 1);
      sounds.update(soundState(seconds: 5, revealed: 2));
      await flush();
      expect(hint.plays + tick.plays, 0);
      hint = FakeEffectPlayer()..failLoading = true;
      tick = FakeEffectPlayer();
      sounds = GameSoundController(hintPlayer: hint, tickPlayer: tick);
      await sounds.initialize();
      sounds.update(soundState(seconds: 6));
      sounds.update(soundState(seconds: 5, revealed: 1));
      await flush();
      expect(hint.plays + tick.plays, 0);
    },
  );
}
