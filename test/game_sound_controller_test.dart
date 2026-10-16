import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:kelime_yarisi/features/game/domain/game_answer_feedback.dart';
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
  String? asset;
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
    asset = path;
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
  bool voting = false,
  AnswerOutcome? outcome,
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
  isVoting: voting,
  answerFeedback: outcome == null
      ? null
      : GameAnswerFeedback(
          questionIndex: questionIndex,
          question: QuestionBank.forSet('quick-v1')[questionIndex],
          outcome: outcome,
          scoreDelta: outcome == AnswerOutcome.correct ? 400 : -400,
        ),
  serverNowMs: 1000 + (questionIndex + 1) * 25000 - seconds * 1000,
);

void main() {
  late FakeEffectPlayer hint;
  late FakeEffectPlayer tick;
  late FakeEffectPlayer correct;
  late FakeEffectPlayer wrong;
  int hintVibrations = 0;
  int wrongVibrations = 0;
  late GameSoundController sounds;
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  setUp(() async {
    hint = FakeEffectPlayer();
    tick = FakeEffectPlayer();
    correct = FakeEffectPlayer();
    wrong = FakeEffectPlayer();
    hintVibrations = 0;
    wrongVibrations = 0;
    sounds = GameSoundController(
      hintPlayer: hint,
      tickPlayer: tick,
      correctPlayer: correct,
      wrongPlayer: wrong,
      hintHaptic: () async {
        hintVibrations++;
      },
      wrongHaptic: () async {
        wrongVibrations++;
      },
    );
    await sounds.initialize();
  });
  tearDown(() => sounds.dispose());

  test('A remote winner plays the reveal cue once without a wrong-answer sound or vibration', () async {
    sounds.update(soundState());
    sounds.update(soundState(outcome: AnswerOutcome.beaten));
    sounds.update(soundState(outcome: AnswerOutcome.beaten));
    await flush();
    expect(hint.plays, 1);
    expect(wrong.plays, 0);
    expect(correct.plays, 0);
    expect(wrongVibrations, 0);
    expect(hintVibrations, 0);
    // A player who previously answered incorrectly still hears the shared reveal.
    sounds.update(soundState(questionIndex: 1));
    sounds.update(soundState(questionIndex: 1, outcome: AnswerOutcome.wrong));
    await flush();
    sounds.update(soundState(questionIndex: 1, outcome: AnswerOutcome.beaten));
    await flush();
    expect(hint.plays, 2);
    expect(wrong.plays, 1);
    expect(wrongVibrations, 1);
  });

  test('Accepted answers sound once; only wrong answers vibrate; stale snapshots and timeouts do not replay', () async {
    expect(correct.asset, 'audio/answer_correct.wav');
    expect(wrong.asset, 'audio/answer_wrong.wav');
    sounds.update(soundState());
    sounds.update(soundState(outcome: AnswerOutcome.wrong));
    sounds.update(soundState(outcome: AnswerOutcome.wrong));
    await flush();
    expect(wrong.plays, 1);
    expect(wrongVibrations, 1);
    expect(correct.plays, 0);
    sounds.update(soundState());
    sounds.update(soundState(outcome: AnswerOutcome.wrong));
    await flush();
    expect(wrong.plays, 1);
    sounds.update(soundState(questionIndex: 1));
    sounds.update(soundState(questionIndex: 1, outcome: AnswerOutcome.correct));
    await flush();
    expect(correct.plays, 1);
    expect(wrongVibrations, 1);
    sounds.update(soundState(questionIndex: 2));
    sounds.update(soundState(questionIndex: 2, outcome: AnswerOutcome.timeout));
    await flush();
    expect(wrong.plays, 1);
    expect(wrongVibrations, 1);
  });

  test(
    'Hint button press vibrates once; a pending vote makes no reveal sound',
    () async {
      sounds.update(soundState());
      sounds.update(soundState(voting: true));
      sounds.update(soundState(voting: true));
      await flush();
      expect(hintVibrations, 1);
      expect(hint.plays, 0);
      sounds.update(soundState(voter: 'guest'));
      sounds.update(soundState(voter: 'guest', revealed: 1));
      await flush();
      expect(hintVibrations, 1);
      expect(hint.plays, 1);
    },
  );

  test(
    'Muted sound keeps haptics; background answers and resuming stay silent',
    () async {
      sounds.update(soundState());
      await sounds.setEnabled(false);
      sounds.update(soundState(voting: true));
      sounds.update(soundState(outcome: AnswerOutcome.wrong));
      await flush();
      expect(hintVibrations, 1);
      expect(wrongVibrations, 1);
      expect(wrong.plays, 0);
      await sounds.setForeground(false);
      sounds.update(soundState(questionIndex: 1));
      sounds.update(
        soundState(
          questionIndex: 1,
          voting: true,
          outcome: AnswerOutcome.wrong,
        ),
      );
      await sounds.setForeground(true);
      await sounds.setEnabled(true);
      sounds.update(soundState(questionIndex: 1, outcome: AnswerOutcome.wrong));
      sounds.update(soundState(questionIndex: 1, outcome: AnswerOutcome.wrong));
      await flush();
      expect(wrongVibrations, 1);
      expect(hintVibrations, 1);
      expect(wrong.plays, 0);
    },
  );

  test('Native haptic calls use light impact for hints and vibration for wrong answers', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final native = GameSoundController(
      hintPlayer: FakeEffectPlayer(),
      tickPlayer: FakeEffectPlayer(),
      correctPlayer: FakeEffectPlayer(),
      wrongPlayer: FakeEffectPlayer(),
    );
    try {
      await native.initialize();
      native.update(soundState());
      native.update(soundState(voting: true));
      native.update(soundState(outcome: AnswerOutcome.wrong));
      await flush();
      expect(calls.map((call) => call.method), [
        'HapticFeedback.vibrate',
        'HapticFeedback.vibrate',
      ]);
      expect(calls.map((call) => call.arguments), [
        'HapticFeedbackType.lightImpact',
        null,
      ]);
    } finally {
      await native.dispose();
    }
  });

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

  test(
    'Leaving cancels an in-flight answer sound before playback starts',
    () async {
      final pending = Completer<void>();
      wrong.stopBarrier = pending.future;
      sounds.update(soundState());
      sounds.update(soundState(outcome: AnswerOutcome.wrong));
      sounds.update(soundState(outcome: AnswerOutcome.wrong, leaving: true));
      pending.complete();
      await flush();
      expect(wrong.plays, 0);
    },
  );

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
      correct = FakeEffectPlayer();
      wrong = FakeEffectPlayer();
      sounds = GameSoundController(
        hintPlayer: hint,
        tickPlayer: tick,
        correctPlayer: correct,
        wrongPlayer: wrong,
        hintHaptic: () async {
          hintVibrations++;
        },
        wrongHaptic: () async {
          wrongVibrations++;
        },
      );
      await sounds.initialize();
      sounds.update(soundState(seconds: 6));
      sounds.update(soundState(seconds: 5, revealed: 1));
      sounds.update(
        soundState(seconds: 5, revealed: 1, outcome: AnswerOutcome.wrong),
      );
      await flush();
      expect(hint.plays + tick.plays, 0);
      expect(wrong.plays, 0);
      expect(wrongVibrations, 1);
    },
  );
}
