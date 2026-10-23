import 'dart:async';

import 'support/fake_native_speech.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/domain/question_race.dart';
import 'package:kelime_yarisi/features/game/domain/shared_hints.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/pages/game_page.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_letter_cell.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_pin_input.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/game_question_card.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_mapper.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;
import 'game_page_test.dart' show FakeGameSounds;

class RaceRoomService extends FakeRoomService {
  final actions = <({String action, int? index, String? input})>[];
  Future<void> Function()? onPlay;

  @override
  Future<void> playRace(
    String roomId, {
    String action = 'sync',
    int? questionIndex,
    String? input,
    int? expectedRevealedCount,
    int? expectedHintCount,
  }) async {
    actions.add((action: action, index: questionIndex, input: input));
    await onPlay?.call();
  }
}

GameRoom raceRoom(int at) => testRoom().copyWith(
  startsAtMs: at,
  gameplayVersion: 'race-v1',
  race: QuestionRace(questionIndex: 0, startedAtMs: at),
);

GameRoom winnerRoom(GameRoom room, int nextAt) => room.copyWith(
  race: QuestionRace(
    questionIndex: 0,
    startedAtMs: room.startsAtMs!,
    nextAtMs: nextAt,
    winnerId: 'host',
    winnerName: 'Arman',
  ),
  progress: const {
    'host': GameProgress(
      questionIndex: 1,
      score: 400,
      correctCount: 1,
      lastOutcome: AnswerOutcome.correct,
      lastScoreDelta: 400,
    ),
    'guest': GameProgress(
      questionIndex: 1,
      skippedCount: 1,
      lastOutcome: AnswerOutcome.beaten,
      lastScoreDelta: 0,
    ),
  },
);

void main() {
  test(
    'answer and letter requests finish independently when both are in flight',
    () async {
      final service = RaceRoomService()..room = raceRoom(1000);
      final letterGate = Completer<void>();
      final answerGate = Completer<void>();
      service.onPlay = () => service.actions.last.action == 'hint'
          ? letterGate.future
          : answerGate.future;
      final game = GameCubit(service, service.room, nowMs: () => 1500);
      service.offsets.add(0);
      service.connections.add(true);
      try {
        final letter = game.revealLetter();
        expect(game.state.isVoting, isTrue);
        final answer = game.submitAnswer('KAPI');
        expect(game.state.isSaving, isTrue);
        letterGate.complete();
        await letter;
        expect(game.state.isVoting, isFalse);
        expect(game.state.isSaving, isTrue);
        answerGate.complete();
        await answer;
        expect(game.state.isSaving, isFalse);
        expect(game.state.canAct, isFalse);
      } finally {
        await game.close();
        await service.disposeStreams();
      }
    },
  );

  test('clue hints are synchronous, local and limited to two per question and ten per game', () async {
    final service = RaceRoomService()..room = raceRoom(1000);
    final game = GameCubit(service, service.room, nowMs: () => 1500);
    service.offsets.add(0);
    service.connections.add(true);
    try {
      for (var index = 0; index < 6; index++) {
        service.publish(
          service.room.copyWith(
            race: QuestionRace(questionIndex: index, startedAtMs: 1000),
            progress: {'guest': GameProgress(questionIndex: index)},
          ),
        );
        game.requestClueHint();
        game.requestClueHint();
        game.requestClueHint();
        expect(game.state.currentClueHintCount, index < 5 ? 2 : 0);
        expect(game.state.remainingClueHints, index < 5 ? 8 - index * 2 : 0);
        expect(game.state.visibleClueHints.length, index < 5 ? 2 : 0);
        expect(game.state.canAct, isTrue);
      }
      expect(service.actions, isEmpty);
      expect(service.room.clueHintUsage, isEmpty);
    } finally {
      await game.close();
      await service.disposeStreams();
    }
  });

  testWidgets(
    'letter request leaves answer and prepared microphone untouched',
    (tester) async {
      final service = RaceRoomService()
        ..room = raceRoom(DateTime.now().millisecondsSinceEpoch - 1000);
      final native = FakeNativeSpeech()..bufferSupported = true;
      final gate = Completer<void>();
      service.onPlay = () => gate.future;
      await tester.pumpWidget(
        withSpeech(
          RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: GamePage(room: service.room, sounds: FakeGameSounds()),
            ),
          ),
          recognizer: native,
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pumpAndSettle();
      final answer = find.byKey(const ValueKey('answer-action'));
      final original = tester.widget<FilledButton>(answer);
      final prepares = native.bufferPreparations;
      final stops = native.bufferStops;
      await tester.tap(find.byKey(const ValueKey('hint-action')));
      await tester.pump();
      final game = tester.element(answer).read<GameCubit>();
      expect(game.state.isVoting, isTrue);
      expect(game.state.canAct, isTrue);
      expect(identical(tester.widget<FilledButton>(answer), original), isTrue);
      expect(tester.widget<FilledButton>(answer).onPressed, isNotNull);
      expect(native.bufferPreparations, prepares);
      expect(native.bufferStops, stops);
      expect(native.bufferActive, isTrue);
      gate.complete();
      await tester.pumpAndSettle();
      expect(game.state.isVoting, isFalse);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final ending in ['timeout', 'winner', 'all-wrong']) {
      testWidgets(
        '$platform: wrong answer stays red and hidden until $ending resolves the shared round',
        (tester) async {
          final service = RaceRoomService()
            ..room = raceRoom(DateTime.now().millisecondsSinceEpoch - 1000)
                .copyWith(hints: const {0: SharedHints(revealedCount: 1)});
          final native = FakeNativeSpeech();
          service.onPlay = () async {
            if (service.actions.last.action != 'answer') return;
            service.publish(
              service.room.copyWith(
                progress: const {
                  'guest': GameProgress(
                    questionIndex: 1,
                    wrongCount: 1,
                    lastOutcome: AnswerOutcome.wrong,
                  ),
                },
              ),
            );
          };
          await tester.pumpWidget(
            withSpeech(
              RepositoryProvider<FirebaseRoomService>.value(
                value: service,
                child: MaterialApp(
                  theme: AppTheme.dark.copyWith(platform: platform),
                  home: GamePage(room: service.room, sounds: FakeGameSounds()),
                ),
              ),
              recognizer: native,
            ),
          );
          service.offsets.add(0);
          service.connections.add(true);
          await tester.pumpAndSettle();
          final button = find.byKey(const ValueKey('answer-action'));
          await tester.tapAt(tester.getCenter(button));
          await tester.pump();
          native.say('yanlış kelime');
          await tester.pump();

          await tester.pumpAndSettle();
          expect(find.text('Yanlış cevap'), findsOneWidget);
          expect(find.text('Doğru cevap: KAPI'), findsNothing);
          var cells = tester.widgetList<WordLetterCell>(
            find.byType(WordLetterCell),
          );
          expect(cells.every((c) => c.outcome == AnswerOutcome.wrong), isTrue);
          expect(cells.where((c) => c.revealed), hasLength(1));
          expect(
            cells.where((c) => !c.revealed).every((c) => c.character == null),
            isTrue,
          );
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          final now = DateTime.now().millisecondsSinceEpoch;
          service.publish(
            service.room.copyWith(
              race: QuestionRace(
                questionIndex: 0,
                startedAtMs: service.room.race!.startedAtMs,
                nextAtMs: now + 2000,
                winnerId: ending == 'winner' ? 'host' : null,
                winnerName: ending == 'winner' ? 'Arman' : null,
                reason: ending == 'all-wrong' ? 'all-wrong' : null,
              ),
            ),
          );
          await tester.pumpAndSettle();
          cells = tester.widgetList<WordLetterCell>(
            find.byType(WordLetterCell),
          );
          expect(cells.map((c) => c.character).join(), 'KAPI');
          expect(find.text('Doğru cevap: KAPI'), findsOneWidget);
          expect(
            find.text(switch (ending) {
              'winner' => 'Arman bildi 😔',
              'all-wrong' => 'Yanlış cevap',
              _ => 'Süre doldu',
            }),
            findsOneWidget,
          );
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          await tester.pumpWidget(const SizedBox());
          await service.disposeStreams();
        },
      );
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final outcome in ['unmatched', 'silence', 'native failure']) {
      testWidgets(
        '$platform: $outcome consumes the voice attempt until the next question even when upload fails',
        (tester) async {
          final service = RaceRoomService()
            ..room = raceRoom(DateTime.now().millisecondsSinceEpoch - 1000);
          final native = FakeNativeSpeech();
          service.onPlay = () async {
            if (service.actions.last.action == 'answer') {
              throw const RoomServiceException(
                'unavailable',
                'Cevap kaydedilemedi.',
              );
            }
          };
          await tester.pumpWidget(
            withSpeech(
              RepositoryProvider<FirebaseRoomService>.value(
                value: service,
                child: MaterialApp(
                  theme: AppTheme.dark.copyWith(platform: platform),
                  home: GamePage(room: service.room, sounds: FakeGameSounds()),
                ),
              ),
              recognizer: native,
            ),
          );
          service.offsets.add(0);
          service.connections.add(true);
          await tester.pumpAndSettle();
          final button = find.byKey(const ValueKey('answer-action'));
          final game = tester.element(button).read<GameCubit>();
          await tester.tapAt(tester.getCenter(button));
          await tester.pump();
          expect(native.starts, 1);
          if (outcome == 'unmatched') {
            native.say('yanlış kelime', finalResult: false);
            await tester.pump();
          }
          await tester.pump(const Duration(seconds: 3));
          if (outcome == 'native failure') {
            native.error!(SpeechRecognitionError('error_network', true));
          }
          await tester.pump(const Duration(seconds: 2));

          await tester.pump();
          expect(
            service.actions.where((a) => a.action == 'answer'),
            hasLength(1),
          );
          expect(service.actions.last.input, '');
          expect(game.state.errorMessage, isNotNull);
          expect(game.state.canAct, isFalse);
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          await tester.tapAt(tester.getCenter(button));
          await tester.pump();

          await game.submitAnswer('kapi');
          await game.revealLetter();
          expect(native.starts, 1);
          expect(
            service.actions.where((a) => a.action == 'answer'),
            hasLength(1),
          );
          service.publish(
            service.room.copyWith(
              race: QuestionRace(
                questionIndex: 1,
                startedAtMs: DateTime.now().millisecondsSinceEpoch - 1,
              ),
            ),
          );
          // A real server advances every player's progress at the round end.
          service.publish(
            service.room.copyWith(
              progress: const {
                'guest': GameProgress(questionIndex: 1, wrongCount: 1),
              },
            ),
          );
          await tester.pumpAndSettle();
          expect(game.state.canAct, isTrue);
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          await tester.pumpWidget(const SizedBox());
          await service.disposeStreams();
        },
      );
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform: hints stay in their card and speech submits the matched answer',
      (tester) async {
        final service = RaceRoomService()
          ..room = raceRoom(DateTime.now().millisecondsSinceEpoch - 1000);
        final native = FakeNativeSpeech()..bufferSupported = true;
        await tester.pumpWidget(
          withSpeech(
            RepositoryProvider<FirebaseRoomService>.value(
              value: service,
              child: MaterialApp(
                theme: AppTheme.dark.copyWith(platform: platform),
                home: GamePage(room: service.room, sounds: FakeGameSounds()),
              ),
            ),
            recognizer: native,
          ),
        );
        service.offsets.add(0);
        service.connections.add(true);
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        final originalPin = tester.widget<WordPinInput>(
          find.byType(WordPinInput),
        );
        final originalAnswer = tester.widget<FilledButton>(
          find.byKey(const ValueKey('answer-action')),
        );
        final preparations = native.bufferPreparations;
        final stops = native.bufferStops;
        for (var i = 0; i < 2; i++) {
          final hint = find.byKey(const ValueKey('clue-hint-action'));
          await tester.ensureVisible(hint);
          await tester.pumpAndSettle();
          await tester.tap(hint);
          await tester.pumpAndSettle();
        }
        expect(
          service.actions,
          isEmpty,
          reason: 'Clue hints must never call the server.',
        );
        expect(
          identical(
            tester.widget<WordPinInput>(find.byType(WordPinInput)),
            originalPin,
          ),
          isTrue,
        );
        expect(
          identical(
            tester.widget<FilledButton>(
              find.byKey(const ValueKey('answer-action')),
            ),
            originalAnswer,
          ),
          isTrue,
        );
        expect(native.bufferPreparations, preparations);
        expect(native.bufferStops, stops);
        expect(native.bufferActive, isTrue);
        final game = tester
            .element(find.byType(WordPinInput))
            .read<GameCubit>();
        expect(game.state.currentClueHintCount, 2);
        expect(
          find.ancestor(
            of: find.byType(WordPinInput),
            matching: find.byType(GameQuestionCard),
          ),
          findsOneWidget,
        );
        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('answer-action'))),
        );
        await tester.pump();
        native.say('ka', finalResult: false);
        await tester.pump();
        expect(service.actions.where((a) => a.action == 'answer'), isEmpty);
        native.say('cevap kapıdır', finalResult: false);
        await tester.pump();
        expect(service.actions.last.action, 'answer');
        expect(service.actions.last.input, 'KAPI');

        native.say('kapı');
        await tester.pump();
        expect(
          service.actions.where((a) => a.action == 'answer'),
          hasLength(1),
        );
        expect(service.saves, isEmpty);
        expect(find.byType(TextField), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.disposeStreams();
      },
    );
  }

  test('authoritative winner locks both clients, preserves loser score and advances before the old deadline', () async {
    final service = RaceRoomService()..room = raceRoom(1000);
    var now = 1000;
    final game = GameCubit(service, service.room, nowMs: () => now);
    try {
      service.offsets.add(0);
      service.connections.add(true);
      await game.submitAnswer('kapi');
      expect(service.actions.single.action, 'answer');
      expect(service.actions.single.input, 'KAPI'.toLowerCase());
      expect(service.saves, isEmpty);
      expect(game.state.progress.score, 0); // No client-assigned points.
      service.publish(winnerRoom(service.room, 3200));
      expect(game.state.answerFeedback!.label, 'Arman bildi 😔');
      expect(game.state.answerFeedback!.scoreDelta, 0);
      expect(game.state.progress.wrongCount, 0);
      expect(game.state.canAct, isFalse);
      await game.submitAnswer('kapi');
      await game.revealLetter();
      expect(service.actions.length, 1);
      now = 3199;
      service.offsets.add(0);
      expect(game.state.questionIndex, 0);
      service.onPlay = () async {
        service.publish(
          service.room.copyWith(
            race: const QuestionRace(questionIndex: 1, startedAtMs: 3200),
          ),
        );
      };
      now = 3200;
      service.offsets.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(service.actions.last.action, 'sync');
      expect(game.state.questionIndex, 1);
      expect(game.state.remainingSeconds, 25);
      expect(game.state.canAct, isTrue);
      expect(service.saves, isEmpty);
      expect(service.resultWrites, 0);
      // The old total clock no longer finishes a still-active race.
      service.publish(
        service.room.copyWith(
          race: const QuestionRace(questionIndex: 1, startedAtMs: 200000),
        ),
      );
      now = 200000;
      service.offsets.add(0);
      expect(game.state.hasExpired, isFalse);
    } finally {
      await game.close();
      await service.disposeStreams();
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform: remote winner cancels the microphone and late voice cannot answer the next question',
      (tester) async {
        final service = RaceRoomService()
          ..room = raceRoom(DateTime.now().millisecondsSinceEpoch - 1000);
        final native = FakeNativeSpeech();
        await tester.pumpWidget(
          withSpeech(
            RepositoryProvider<FirebaseRoomService>.value(
              value: service,
              child: MaterialApp(
                theme: AppTheme.dark.copyWith(platform: platform),
                home: GamePage(room: service.room, sounds: FakeGameSounds()),
              ),
            ),
            recognizer: native,
          ),
        );
        service.offsets.add(0);
        service.connections.add(true);
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('answer-action'))),
        );
        await tester.pump();
        native.say('ka', finalResult: false);
        await tester.pump();
        service.publish(
          winnerRoom(
            service.room,
            DateTime.now().millisecondsSinceEpoch + 2000,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();
        expect(find.text('Arman bildi 😔'), findsOneWidget);
        expect(native.cancels, greaterThan(0));
        expect(
          tester
              .widgetList<WordLetterCell>(find.byType(WordLetterCell))
              .map((c) => c.character)
              .join(),
          'KAPI',
        );
        expect(
          tester
              .widgetList<WordLetterCell>(find.byType(WordLetterCell))
              .every((c) => c.outcome == AnswerOutcome.beaten),
          isTrue,
        );
        service.publish(
          service.room.copyWith(
            race: QuestionRace(
              questionIndex: 1,
              startedAtMs: DateTime.now().millisecondsSinceEpoch - 1,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        native.say('kapıdır');

        await tester.pump();
        expect(service.actions.where((a) => a.action == 'answer'), isEmpty);
        expect(
          tester
              .widget<WordPinInput>(find.byType(WordPinInput))
              .answerController
              .text,
          isEmpty,
        );
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.disposeStreams();
      },
    );
  }

  test(
    'mapper retains race timing, winner and neutral progress from the server',
    () {
      final original = raceRoom(1000);
      final mapped = FirebaseRoomMapper.fromMap(original.id, {
        ...FirebaseRoomMapper.toMap(original),
        'race': {
          'questionIndex': 0,
          'startedAtMs': 1000,
          'nextAtMs': 3200,
          'winnerId': 'host',
          'winnerName': 'Arman',
        },
        'progress': {
          'guest': {
            'questionIndex': 1,
            'score': 0,
            'correctCount': 0,
            'wrongCount': 0,
            'skippedCount': 1,
            'finished': false,
            'lastOutcome': 'beaten',
            'lastScoreDelta': 0,
          },
        },
      });
      expect(mapped.race!.winnerName, 'Arman');
      expect(mapped.race!.nextAtMs, 3200);
      expect(mapped.progress['guest']!.skippedCount, 1);
      expect(mapped.progress['guest']!.lastOutcome, AnswerOutcome.beaten);
    },
  );
}
