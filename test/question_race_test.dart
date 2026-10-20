import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/domain/question_race.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/pages/game_page.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_letter_cell.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_pin_input.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/game_question_card.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/game_clue_hints.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/answer_feedback_banner.dart';
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
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform: the existing card scrolls its clue, hints and PIN above the keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final service = RaceRoomService()
          ..room = raceRoom(DateTime.now().millisecondsSinceEpoch - 1000);
        service.onPlay = () async {
          if (service.actions.last.action != 'clueHint') return;
          final used = service.room.clueHintUsage[service.uid]?[0] ?? 0;
          service.publish(
            service.room.copyWith(
              clueHintUsage: {
                service.uid: {0: used + 1},
              },
            ),
          );
        };
        await tester.pumpWidget(
          RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.dark.copyWith(platform: platform),
              home: GamePage(room: service.room, sounds: FakeGameSounds()),
            ),
          ),
        );
        service.offsets.add(0);
        service.connections.add(true);
        await tester.pump();
        await tester.showKeyboard(find.byType(TextField));
        final focus = tester
            .widget<TextField>(find.byType(TextField))
            .focusNode!;
        final connection = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        await tester.enterText(find.byType(TextField), 'ka');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        final actionsRect = tester.getRect(
          find.byKey(const ValueKey('answer-action')),
        );
        final action = find.byKey(const ValueKey('clue-hint-action'));
        expect(find.text('10/10'), findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('9/10'), findsOneWidget);
        expect(find.text('1. Koluna basıp içeri geçeriz.'), findsOneWidget);
        expect(focus.hasFocus, isTrue);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('8/10'), findsOneWidget);
        expect(tester.widget<TextButton>(action).onPressed, isNull);
        expect(
          service.actions.where((a) => a.action == 'clueHint'),
          hasLength(2),
        );
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(connection),
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'KA',
        );
        expect(
          find.ancestor(
            of: find.byType(WordPinInput),
            matching: find.byType(GameQuestionCard),
          ),
          findsOneWidget,
        );
        final viewport = tester.getRect(find.byType(ListView));
        final pinRect = tester.getRect(find.byType(WordPinInput));
        final game = tester
            .element(find.byType(WordPinInput))
            .read<GameCubit>();
        final clueRect = tester.getRect(find.text(game.state.question!.clue));
        final hintRect = tester.getRect(find.byType(GameClueHints));
        expect(clueRect.top, greaterThanOrEqualTo(viewport.top));
        expect(hintRect.top, greaterThanOrEqualTo(clueRect.bottom));
        expect(hintRect.bottom, lessThanOrEqualTo(pinRect.top));
        expect(pinRect.bottom + 8, lessThanOrEqualTo(viewport.bottom));
        expect(
          tester.getRect(find.byKey(const ValueKey('answer-action'))),
          actionsRect,
        );
        expect(actionsRect.bottom, lessThanOrEqualTo(540));
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          greaterThan(0),
        );
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
      '$platform: remote winner reveals and scrolls PIN plus feedback above keyboard, then resets the answer',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final at = DateTime.now().millisecondsSinceEpoch - 1000;
        final service = RaceRoomService()
          ..room = raceRoom(at).copyWith(
            clueHintUsage: const {
              'guest': {0: 2},
            },
          );
        await tester.pumpWidget(
          RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.dark.copyWith(platform: platform),
              home: GamePage(room: service.room, sounds: FakeGameSounds()),
            ),
          ),
        );
        service.offsets.add(0);
        service.connections.add(true);
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'sa');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final focus = tester
            .widget<TextField>(find.byType(TextField))
            .focusNode!;
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        final beforeAnswerOffset = position.pixels;
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
        final viewport = tester.getRect(find.byType(ListView));
        final pin = tester.getRect(find.byType(WordPinInput));
        final feedback = tester.getRect(find.byType(AnswerFeedbackBanner));
        expect(pin.top, greaterThanOrEqualTo(viewport.top));
        expect(pin.bottom, lessThanOrEqualTo(feedback.top));
        expect(feedback.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(position.pixels, greaterThan(beforeAnswerOffset));
        expect(
          tester
              .widget<WordPinInput>(find.byType(WordPinInput))
              .answerController
              .text,
          'KAPI',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'KAPI',
        );
        final cells = tester.widgetList<WordLetterCell>(
          find.byType(WordLetterCell),
        );
        expect(cells.map((c) => c.character).join(), 'KAPI');
        expect(cells.every((c) => c.outcome == AnswerOutcome.beaten), isTrue);
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
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
        expect(
          tester.widget<WordPinInput>(find.byType(WordPinInput)).questionIndex,
          1,
        );
        expect(
          tester
              .widget<WordPinInput>(find.byType(WordPinInput))
              .answerController
              .text,
          isEmpty,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(focus.hasFocus, isTrue);
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
