import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kelime_yarisi/main.dart' as app;
import 'package:kelime_yarisi/core/config/question_environment.dart';
import 'package:kelime_yarisi/features/game/data/question_history_store.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real dev device: complete a set, exclude it next game, keep abandoned sets playable',
    (tester) async {
      expect(const String.fromEnvironment('FLUTTER_APP_FLAVOR'), 'dev');
      expect(QuestionEnvironment.enabled, isTrue);
      await app.main();
      await tester.pumpAndSettle();
      final firebase = Firebase.app();
      expect(firebase.options.projectId, 'kelime-yarisi-yalin');
      final file =
          '${await getDatabasesPath()}/set-device-test-${DateTime.now().microsecondsSinceEpoch}.sqlite';
      final store = QuestionHistoryStore(databasePath: file);
      final service = FirebaseRoomService(
        auth: FirebaseAuth.instanceFor(app: firebase),
        database: FirebaseDatabase.instanceFor(app: firebase),
        functions: FirebaseFunctions.instanceFor(
          app: firebase,
          region: 'europe-west1',
        ),
        questionHistory: store,
      );
      final rooms = <GameRoom>[];
      GameCubit? game;
      addTearDown(() async {
        await game?.close();
        for (final room in rooms) {
          await service.leaveRoom(room.id);
        }
        await service.dispose();
        await deleteDatabase(file);
      });
      Future<void> waitUntil(bool Function() condition) async {
        final until = DateTime.now().add(const Duration(seconds: 20));
        while (!condition() && DateTime.now().isBefore(until)) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(condition(), isTrue);
      }

      Future<GameRoom> create() async {
        final room = await service.createRoom(
          displayName: 'Cihaz testi',
          roomName: 'Tam set cihaz testi',
          targetPlayerCount: 2,
          gameMode: RoomGameMode.classic,
        );
        rooms.add(room);
        // Only IDs for cleanup, never Auth/App Check tokens or question answers.
        // ignore: avoid_print
        print('KY_DEVICE_TEST_ROOM=${room.id};uid=${service.currentUserId}');
        return room;
      }

      Future<GameRoom> start(GameRoom room) async {
        await service.startCountdown(
          room.id,
          serverTimeOffsetMs: 0,
          gameMode: RoomGameMode.classic,
          questionEngine: room.questionEngine,
        );
        final started = await service
            .watchRoom(room.id)
            .firstWhere((r) => r.status == RoomStatus.countdown)
            .timeout(const Duration(seconds: 20));
        expect(started.contentSetId, isNotEmpty);
        expect(started.questions, hasLength(14));
        // ignore: avoid_print
        print(
          'KY_DEVICE_TEST_SESSION=${started.questionSetId!.substring(8)};room=${room.id}',
        );
        final offset = await service.watchServerTimeOffset().first;
        final remaining =
            started.startsAtMs! -
            (DateTime.now().millisecondsSinceEpoch + offset);
        if (remaining > 0) {
          await Future<void>.delayed(Duration(milliseconds: remaining + 200));
        }
        await service.markPlaying(room.id);
        final playing = await service
            .watchRoom(room.id)
            .firstWhere((r) => r.status == RoomStatus.playing)
            .timeout(const Duration(seconds: 20));
        game = GameCubit(service, playing)..setForeground(true);
        return playing;
      }

      final first = await create();
      final before = await service.prepareQuestionHistory(first.id);
      final firstSet = await start(first);
      expect(firstSet.questions.every((q) => q.hints.length == 2), isTrue);
      await waitUntil(() => game!.state.canRequestClueHint);
      await game!.requestClueHint();
      await waitUntil(() => game!.state.visibleClueHints.length == 1);
      expect(game!.state.remainingClueHints, 9);
      await game!.requestClueHint();
      await waitUntil(() => game!.state.visibleClueHints.length == 2);
      expect(game!.state.remainingClueHints, 8);
      expect(game!.state.canRequestClueHint, isFalse);
      final reconnectRoom = game!.state.room;
      await game!.close();
      game = GameCubit(service, reconnectRoom)..setForeground(true);
      await waitUntil(() => game!.state.canAct);
      expect(game!.state.remainingClueHints, 8);
      expect(game!.state.visibleClueHints, hasLength(2));
      for (var index = 0; index < 14; index++) {
        await waitUntil(
          () => game!.state.questionIndex == index && game!.state.canAct,
        );
        await game!.submitAnswer(game!.state.question!.answer);
        await waitUntil(() => game!.state.progress.questionIndex == index + 1);
      }
      await waitUntil(() => game!.state.progress.finished);
      await game!.leaveRoom(); // Awaits the real SQLite completion commit.
      await game!.close();
      game = null;
      expect((await store.snapshot())['completedSetIds'], [
        firstSet.contentSetId,
      ]);
      final second = await create();
      final after = await service.prepareQuestionHistory(second.id);
      expect(after['availableSets'], (before['availableSets'] as int) - 1);
      final secondSet = await start(second);
      expect(game!.state.remainingClueHints, 10);
      expect(secondSet.contentSetId, isNot(firstSet.contentSetId));
      final database = FirebaseDatabase.instanceFor(app: firebase);
      await expectLater(
        database.ref('rooms/${second.id}/contentSetId').set('forged'),
        throwsA(isA<FirebaseException>()),
      );
      for (var index = 0; index < 3; index++) {
        await waitUntil(
          () => game!.state.questionIndex == index && game!.state.canAct,
        );
        await game!.submitAnswer(game!.state.question!.answer);
        await waitUntil(() => game!.state.progress.questionIndex == index + 1);
      }
      await game!.leaveRoom();
      await game!.close();
      game = null;
      expect((await store.snapshot())['completedSetIds'], [
        firstSet.contentSetId,
      ]);
      final third = await create();
      final replay = await service.prepareQuestionHistory(third.id);
      expect(replay['availableSets'], after['availableSets']);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
