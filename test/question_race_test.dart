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

  testWidgets(
    'remote winner fills the controller and PIN, animates banner, keeps keyboard and resets the next answer',
    (tester) async {
      final at = DateTime.now().millisecondsSinceEpoch - 1000;
      final service = RaceRoomService()..room = raceRoom(at);
      await tester.pumpWidget(
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
            home: GamePage(room: service.room, sounds: FakeGameSounds()),
          ),
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'sa');
      final focus = tester.widget<TextField>(find.byType(TextField)).focusNode!;
      service.publish(
        winnerRoom(service.room, DateTime.now().millisecondsSinceEpoch + 2000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Arman bildi 😔'), findsOneWidget);
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
