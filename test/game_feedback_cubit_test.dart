import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_feedback_cubit.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;

void main() {
  testWidgets(
    'Timeout feedback retains the old answer for three seconds without delaying the next round',
    (tester) async {
      final service = FakeRoomService()..room = testRoom();
      var now = 1000;
      final game = GameCubit(service, service.room, nowMs: () => now);
      final feedback = GameFeedbackCubit(game);
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      now = 26000;
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(game.state.questionIndex, 1);
      expect(game.state.canAct, isTrue);
      expect(game.state.progress.score, -400);
      expect(feedback.state!.questionIndex, 0);
      expect(feedback.state!.question.answer, 'KAPI');
      expect(feedback.state!.outcome, AnswerOutcome.timeout);
      await tester.pump(const Duration(seconds: 3));
      expect(feedback.state, isNull);
      expect(game.state.questionIndex, 1);
      await tester.runAsync(() async {
        await feedback.close();
        await game.close();
        await service.disposeStreams();
      });
    },
  );

  testWidgets(
    'Failed writes show no success feedback; incomplete input and stale give-up lose no points',
    (tester) async {
      final service = FakeRoomService()..room = testRoom();
      var now = 1000;
      final game = GameCubit(service, service.room, nowMs: () => now);
      final feedback = GameFeedbackCubit(game);
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      await game.submitAnswer('ka');
      expect(service.saves, isEmpty);
      expect(game.state.errorMessage, 'Tüm boş harfleri doldur.');
      service.onSave = (_) async => throw StateError('offline');
      await game.submitAnswer('kapi');
      await tester.pump();
      expect(feedback.state, isNull);
      expect(game.state.progress.score, 0);
      service.onSave = null;
      now = 26000;
      await game.giveUp(questionIndex: 0);
      await tester.pump();
      expect(game.state.questionIndex, 1);
      expect(
        service.saves.where(
          (progress) => progress.lastOutcome == AnswerOutcome.wrong,
        ),
        isEmpty,
      );
      await tester.runAsync(() async {
        await feedback.close();
        await game.close();
        await service.disposeStreams();
      });
    },
  );
}
