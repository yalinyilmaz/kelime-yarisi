import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelime_yarisi/main.dart' as app;
import 'package:kelime_yarisi/features/game/data/question_history_store.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native callable session and device-local SQLite history', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final firebase = Firebase.app('question-pool-emulator');
    expect(firebase.options.projectId, 'demo-kelime-yarisi');
    final service = FirebaseRoomService(
      auth: FirebaseAuth.instanceFor(app: firebase),
      database: FirebaseDatabase.instanceFor(app: firebase),
      functions: FirebaseFunctions.instanceFor(
        app: firebase,
        region: 'europe-west1',
      ),
    );
    final room = await service.createRoom(
      displayName: 'Test',
      roomName: 'Emulator testi',
      targetPlayerCount: 2,
      gameMode: RoomGameMode.classic,
    );
    addTearDown(() async {
      await service.leaveRoom(room.id);
      await service.dispose();
    });
    await service.startCountdown(
      room.id,
      serverTimeOffsetMs: 0,
      gameMode: RoomGameMode.classic,
    );
    final session = await service
        .watchRoom(room.id)
        .firstWhere((room) => room.status == RoomStatus.countdown);
    expect(session.usesQuestionPool, isTrue);
    expect(session.questions.length, 14);
    expect(session.questionOrigin, 'production');
    final first = session.questions.first;
    await service.recordQuestionShown(first);
    await service.recordQuestionShown(
      GameQuestion(
        id: '${first.id}_variant',
        answerId: first.answerId,
        clue: 'Test variation',
        answer: first.answer,
      ),
    );
    // A fresh native SQLite connection sees the persisted IDs, without clue text.
    final history = QuestionHistoryStore();
    final saved = await history.snapshot();
    expect(saved['seenAnswerIds'], contains(first.answerId));
    expect(
      saved['seenQuestionIds'],
      containsAll([first.id, '${first.id}_variant']),
    );
    await history.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
