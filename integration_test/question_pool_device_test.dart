import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelime_yarisi/main.dart' as app;
import 'package:kelime_yarisi/core/config/question_environment.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real dev device: App Check, room and callable access', (
    tester,
  ) async {
    expect(const String.fromEnvironment('FLUTTER_APP_FLAVOR'), 'dev');
    await app.main();
    await tester.pumpAndSettle();
    final firebase = Firebase.app();
    expect(firebase.options.projectId, 'kelime-yarisi-yalin');
    // Never print the returned credential. A placeholder cannot pass this check.
    final token = await FirebaseAppCheck.instanceFor(app: firebase)
        .getToken(true);
    expect(token, isNotEmpty);
    final service = FirebaseRoomService(
      auth: FirebaseAuth.instanceFor(app: firebase),
      database: FirebaseDatabase.instanceFor(app: firebase),
      functions: FirebaseFunctions.instanceFor(
        app: firebase,
        region: 'europe-west1',
      ),
    );
    final room = await service.createRoom(
      displayName: 'Cihaz testi',
      roomName: 'Otomatik cihaz testi',
      targetPlayerCount: 2,
      gameMode: RoomGameMode.classic,
    );
    addTearDown(() async {
      try {
        await service.leaveRoom(room.id);
      } finally {
        await service.dispose();
      }
    });
    final created = await service
        .watchRoom(room.id)
        .firstWhere((room) => room.status == RoomStatus.lobby)
        .timeout(const Duration(seconds: 20));
    expect(
      created.questionEngine,
      QuestionEnvironment.enabled ? 'pool-v1' : 'demo-v1',
    );
    expect(created.hostId, service.currentUserId);
    // Only identifiers for cleanup are logged; no auth/App Check token is logged.
    // ignore: avoid_print
    print('KY_DEVICE_TEST_ROOM=${room.id};uid=${service.currentUserId}');
    if (QuestionEnvironment.enabled) {
      final capacity = await service.prepareQuestionHistory(room.id);
      final groups = capacity['groups'] as List;
      expect(groups, hasLength(7));
      expect(
        groups.every((group) => (group['publishedAnswers'] as num) > 0),
        isTrue,
      );
    } else {
      // Exercise the same protected callable that starts the normal dev game.
      await service.startCountdown(
        room.id,
        serverTimeOffsetMs: 0,
        gameMode: RoomGameMode.classic,
      );
      final started = await service
          .watchRoom(room.id)
          .firstWhere((room) => room.status == RoomStatus.countdown)
          .timeout(const Duration(seconds: 20));
      expect(started.gameplayVersion, 'race-v1');
      expect(started.questions, hasLength(14));
      expect(started.race, isNotNull);
      final offset = await service.watchServerTimeOffset().first;
      final remainingMs =
          started.race!.startedAtMs -
          (DateTime.now().millisecondsSinceEpoch + offset);
      if (remainingMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: remainingMs + 250));
      }
      await service.playRace(
        room.id,
        action: 'answer',
        questionIndex: 0,
        input: started.questions.first.answer,
      );
      final answered = await service
          .watchRoom(room.id)
          .firstWhere((room) => room.race?.winnerId == service.currentUserId)
          .timeout(const Duration(seconds: 20));
      expect(answered.progress[service.currentUserId]?.correctCount, 1);
      expect(answered.progress[service.currentUserId]?.score, greaterThan(0));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
