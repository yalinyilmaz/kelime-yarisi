import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_player.dart';

GameRoom testRoom({
  RoomGameMode mode = RoomGameMode.quick,
  Map<String, GameProgress> progress = const {},
}) => GameRoom(
  id: 'abc234',
  name: 'Test Odası',
  code: 'ABC-234',
  hostId: 'host',
  targetPlayerCount: 2,
  gameMode: mode,
  status: RoomStatus.playing,
  startsAtMs: 1000,
  questionSetId: '${mode.name}-v1',
  progress: progress,
  players: const [
    RoomPlayer(id: 'host', displayName: 'Yalın', isHost: true),
    RoomPlayer(id: 'guest', displayName: 'Misafir'),
  ],
);

class FakeRoomService extends Fake implements FirebaseRoomService {
  final rooms = StreamController<GameRoom>.broadcast(sync: true);
  final offsets = StreamController<int>.broadcast(sync: true);
  final connections = StreamController<bool>.broadcast(sync: true);
  final saves = <GameProgress>[];
  Future<void> Function(GameProgress)? onSave;
  int resultWrites = 0;

  @override
  String get currentUserId => 'guest';
  @override
  Stream<GameRoom> watchRoom(String roomId) => rooms.stream;
  @override
  Stream<int> watchServerTimeOffset() => offsets.stream;
  @override
  Stream<bool> watchConnection() => connections.stream;
  @override
  Future<void> saveProgress(String roomId, GameProgress progress) async {
    saves.add(progress);
    await onSave?.call(progress);
  }

  @override
  Future<void> markResults(String roomId) async {
    resultWrites++;
  }

  Future<void> disposeStreams() async {
    await rooms.close();
    await offsets.close();
    await connections.close();
  }
}

void main() {
  late FakeRoomService service;
  late GameCubit cubit;
  var now = 1000;
  setUp(() {
    service = FakeRoomService();
    now = 1000;
  });
  tearDown(() async {
    await cubit.close();
    await service.disposeStreams();
  });

  void connect() {
    service.offsets.add(0);
    service.connections.add(true);
  }

  test(
    'No action before server clock, connectivity, or synchronized start',
    () async {
      cubit = GameCubit(service, testRoom(), nowMs: () => now);
      await cubit.submitAnswer('kapı');
      expect(service.saves, isEmpty);
      service.offsets.add(-500);
      service.connections.add(true);
      await cubit.submitAnswer('kapı');
      expect(service.saves, isEmpty);
      service.offsets.add(0);
      await cubit.submitAnswer('kapı');
      expect(cubit.state.progress.score, 400);
    },
  );

  test('Write failure restores acknowledged progress despite optimistic Firebase event', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    connect();
    service.onSave = (next) async {
      service.rooms.add(testRoom(progress: {'guest': next}));
      throw StateError('permission-denied');
    };
    await cubit.submitAnswer('kapı');
    expect(cubit.state.progress, const GameProgress());
    expect(cubit.state.isSaving, isFalse);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test(
    'Double submit cannot resolve two questions while one write is pending',
    () async {
      cubit = GameCubit(service, testRoom(), nowMs: () => now);
      connect();
      final pending = Completer<void>();
      service.onSave = (_) => pending.future;
      final first = cubit.submitAnswer('kapı');
      await cubit.submitAnswer('kitap');
      expect(service.saves.length, 1);
      pending.complete();
      await first;
      expect(cubit.state.progress.questionIndex, 1);
    },
  );

  test('Rejected in-flight answer at deadline is rolled back before timeout penalty', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    connect();
    final pending = Completer<void>();
    service.onSave = (next) async {
      if (service.saves.length == 1) {
        service.rooms.add(testRoom(progress: {'guest': next}));
        await pending.future;
      }
    };
    final answer = cubit.submitAnswer('kapı');
    now = 121000;
    pending.completeError(StateError('deadline passed'));
    await answer;
    expect(cubit.state.progress, const GameProgress());
    now += 3001;
    service.offsets.add(0);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.progress.score, -400);
    expect(cubit.state.progress.correctCount, 0);
    expect(cubit.state.progress.wrongCount, 1);
    expect(cubit.state.progress.finished, isTrue);
  });

  test('Deadline rejects guesses, penalizes open question, and guest can close round', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    connect();
    now = 121000;
    await cubit.submitAnswer('kapı');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.progress.score, -400);
    expect(cubit.state.progress.finished, isTrue);
    expect(service.resultWrites, 1);
    service.rooms.add(
      testRoom(progress: {'guest': cubit.state.progress})
          .copyWith(status: RoomStatus.results),
    );
    await cubit.giveUp();
    expect(service.saves.length, 1);
    expect(service.resultWrites, 1);
  });

  test(
    'All questions can finish early; results wait for shared deadline',
    () async {
      cubit = GameCubit(service, testRoom(), nowMs: () => now);
      connect();
      for (final question in cubit.state.questions) {
        await cubit.submitAnswer(question.answer);
      }
      expect(cubit.state.progress.score, 4900);
      expect(cubit.state.progress.finished, isTrue);
      expect(service.resultWrites, 0);
      now = 121000;
      service.offsets.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(service.resultWrites, 1);
      expect(service.saves.length, 7);
    },
  );

  test(
    'Classic deadline uses four minutes and reconnect resumes own stored hints',
    () async {
      const saved = GameProgress(
        questionIndex: 3,
        score: 1000,
        revealedMask: 2,
        correctCount: 2,
        wrongCount: 1,
      );
      cubit = GameCubit(
        service,
        testRoom(mode: RoomGameMode.classic, progress: {'guest': saved}),
        nowMs: () => now,
      );
      connect();
      expect(cubit.state.progress, saved);
      now = 121000;
      service.offsets.add(0);
      expect(cubit.state.remainingSeconds, 120);
      service.connections.add(false);
      now = 241000;
      await cubit.submitAnswer('deniz');
      expect(service.saves, isEmpty);
      service.connections.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.progress.score, 600);
      expect(cubit.state.progress.finished, isTrue);
    },
  );
}
