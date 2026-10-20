import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelime_yarisi/features/game/data/question_bank.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:kelime_yarisi/features/game/domain/game_question_set.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_best_score_cubit.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_game_cubit.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_game_state.dart';

import 'game_cubit_test.dart' show FakeRoomService;
import 'game_page_test.dart' show FakeGameSounds;

GameQuestionSet testSoloSet() => GameQuestionSet(
  id: 'initial_solo_test',
  questions: [
    for (final (index, q) in QuestionBank.forSet('classic-v1').indexed)
      GameQuestion(
        id: 'q_$index',
        answerId: 'a_$index',
        clue: q.clue,
        answer: q.answer,
        hints: q.hints,
        acceptedAnswers: q.acceptedAnswers,
      ),
  ],
);

class MemoryScoreStorage implements Storage {
  final values = <String, dynamic>{};
  bool closed = false;
  @override
  dynamic read(String key) => values[key];
  @override
  Future<void> write(String key, dynamic value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class SilentSoloSounds extends FakeGameSounds {
  int reveals = 0;
  int disposals = 0;
  final answers = <bool>[];
  @override
  void playLetterReveal() {
    reveals++;
  }

  @override
  void playAnswerFeedback(bool correct) {
    answers.add(correct);
  }

  @override
  void playClockTick() {}
  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class SoloTestService extends FakeRoomService {
  final completed = <String>[];
  Completer<GameQuestionSet>? loadGate;
  Completer<void>? saveGate;
  bool failSave = false;
  int loads = 0;
  @override
  Future<GameQuestionSet> loadSoloSet() async {
    loads++;
    return loadGate == null ? testSoloSet() : await loadGate!.future;
  }

  @override
  Future<void> recordCompletedSet(String setId) async {
    await saveGate?.future;
    if (failSave) throw StateError('disk error');
    completed.add(setId);
  }
}

void main() {
  late SoloTestService service;
  late SoloBestScoreCubit best;
  late SoloGameCubit game;
  late SilentSoloSounds sounds;
  var now = 1000;
  void initialize() {
    service = SoloTestService();
    best = SoloBestScoreCubit(storage: MemoryScoreStorage());
    sounds = SilentSoloSounds();
    now = 1000;
    game = SoloGameCubit(service, best, sounds: sounds, nowMs: () => now);
  }

  Future<void> cleanup() async {
    await game.close();
    await best.close();
    await service.disposeStreams();
  }

  void soloTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      initialize();
      try {
        await body(tester);
      } finally {
        await cleanup();
      }
    });
  }

  Future<void> advance(WidgetTester tester) async {
    now += 1200;
    await tester.pump(const Duration(milliseconds: 1200));
  }

  Future<void> finish(WidgetTester tester) async {
    await game.start();
    for (var i = 0; i < 14; i++) {
      game.submitAnswer(game.state.question!.answer);
      await advance(tester);
    }
  }

  soloTest(
    'one 4:20 clock covers fourteen questions and a perfect game saves 9800 once',
    (tester) async {
      await finish(tester);
      expect(game.state.phase, SoloGamePhase.completed);
      expect(game.state.progress.score, 9800);
      expect(best.state, 9800);
      expect(service.completed, ['initial_solo_test']);
      expect(service.loads, 1);
      await game.saveCompletion();
      expect(service.completed, hasLength(1));
      expect(game.state.remainingSeconds, lessThan(260));
    },
  );

  soloTest('abandoning a partial game saves neither its score nor its set', (
    tester,
  ) async {
    await game.start();
    game.submitAnswer('kapi');
    await advance(tester);
    game.leave();
    expect(service.completed, isEmpty);
    expect(best.state, isNull);
    expect(game.state.progress.score, 400);
    expect(game.state.isLeaving, isTrue);
  });

  soloTest(
    'global deadline survives background and never resets on the next question',
    (tester) async {
      await game.start();
      now += 60000;
      game.refreshTime();
      expect(game.state.remainingSeconds, 200);
      game.submitAnswer('kapi');
      await advance(tester);
      expect(game.state.remainingSeconds, lessThanOrEqualTo(199));
      game.setForeground(false);
      now = 1000 + 260000;
      game.setForeground(true);
      expect(game.state.phase, SoloGamePhase.expired);
      game.submitAnswer(game.state.question!.answer);
      expect(service.completed, isEmpty);
      expect(best.state, 400);
    },
  );

  soloTest(
    'expiry at question six persists the earned score but leaves the set replayable',
    (tester) async {
      final storage = MemoryScoreStorage();
      await game.close();
      await best.close();
      best = SoloBestScoreCubit(storage: storage);
      sounds = SilentSoloSounds();
      game = SoloGameCubit(service, best, sounds: sounds, nowMs: () => now);
      // Expiry must not attempt the completed-set write, even if it would fail.
      service.failSave = true;
      await game.start();
      for (var i = 0; i < 5; i++) {
        game.submitAnswer(game.state.question!.answer);
        await advance(tester);
      }
      expect(game.state.questionIndex, 5);
      final earned = game.state.progress.score;
      expect(earned, greaterThan(0));
      now = 1000 + SoloGameState.duration.inMilliseconds;
      game.refreshTime();
      await game.saveCompletion();
      expect(game.state.phase, SoloGamePhase.expired);
      expect(game.state.remainingSeconds, 0);
      expect(game.state.completionSaved, isTrue);
      expect(game.state.progress.finished, isFalse);
      expect(game.state.progress.score, earned);
      expect(service.completed, isEmpty);
      expect(best.state, earned);

      // Later deadline checks and a new cubit must preserve the same result.
      game.refreshTime();
      await game.saveCompletion();
      await best.close();
      best = SoloBestScoreCubit(storage: storage);
      expect(best.state, earned);
      expect(service.completed, isEmpty);
    },
  );

  soloTest('a timeout score never replaces a higher personal best', (
    tester,
  ) async {
    best.recordCompletedScore(7200);
    await game.start();
    game.submitAnswer(game.state.question!.answer);
    await advance(tester);
    now = 1000 + SoloGameState.duration.inMilliseconds;
    game.refreshTime();
    await game.saveCompletion();
    expect(game.state.completionSaved, isTrue);
    expect(best.state, 7200);
    expect(service.completed, isEmpty);
  });

  soloTest(
    'letters open without voting, reduce question value and keep one letter hidden',
    (tester) async {
      await game.start();
      game.revealLetter();
      expect(game.state.revealedCount, 1);
      expect(game.state.questionValue, 300);
      expect(game.state.revealedMask, isNot(0));
      game.submitAnswer('kapi');
      expect(game.state.progress.score, 300);
      expect(sounds.answers, [true]);
      await advance(tester);
      for (var i = 0; i < 10; i++) {
        game.revealLetter();
      }
      expect(game.state.revealedCount, 3);
      expect(game.state.canRevealLetter, isFalse);
      expect(sounds.reveals, 4);
    },
  );

  soloTest(
    'hint budget stays ten across questions, two per question and no point charge',
    (tester) async {
      await game.start();
      for (var i = 0; i < 5; i++) {
        final score = game.state.progress.score;
        for (var n = 0; n < 3; n++) {
          game.requestHint();
        }
        expect(game.state.visibleHints, hasLength(2));
        expect(game.state.progress.score, score);
        game.submitAnswer(game.state.question!.answer);
        await advance(tester);
      }
      expect(game.state.remainingHints, 0);
      game.requestHint();
      expect(game.state.visibleHints, isEmpty);
    },
  );

  soloTest(
    'invalid length costs nothing; a wrong answer reveals the answer and loses its value',
    (tester) async {
      await game.start();
      game.submitAnswer('a');
      expect(game.state.progress.questionIndex, 0);
      expect(game.state.progress.score, 0);
      game.submitAnswer('xxxx');
      expect(game.state.feedback!.question.answer, 'KAPI');
      expect(game.state.progress.score, -400);
      expect(sounds.answers, [false]);
      game.submitAnswer('kapi');
      expect(game.state.progress.score, -400);
      await advance(tester);
      expect(game.state.questionIndex, 1);
    },
  );

  soloTest(
    'failed completion storage can be retried without prematurely changing best score',
    (tester) async {
      service.failSave = true;
      await finish(tester);
      expect(game.state.progress.finished, isTrue);
      expect(game.state.completionSaved, isFalse);
      expect(best.state, isNull);
      service.failSave = false;
      await game.saveCompletion();
      expect(game.state.completionSaved, isTrue);
      expect(best.state, 9800);
    },
  );

  soloTest(
    'closing while the final save is pending still records a completed game',
    (tester) async {
      service.saveGate = Completer<void>();
      await finish(tester);
      final closing = game.close();
      expect(game.isClosed, isTrue);
      service.saveGate!.complete();
      await closing;
      expect(service.completed, ['initial_solo_test']);
      expect(best.state, 9800);
    },
  );

  soloTest(
    'closing during set loading never starts a late timer or records history',
    (tester) async {
      service.loadGate = Completer<GameQuestionSet>();
      final starting = game.start();
      await game.close();
      service.loadGate!.complete(testSoloSet());
      await starting;
      expect(service.completed, isEmpty);
      expect(game.isClosed, isTrue);
    },
  );
}
