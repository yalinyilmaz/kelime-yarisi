import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/domain/shared_hints.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_mapper.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_player.dart';

GameRoom testRoom({
  RoomGameMode mode = RoomGameMode.quick,
  int playerCount = 2,
  Map<String, GameProgress> progress = const {},
  Map<int, SharedHints> hints = const {},
}) => GameRoom(
  id: 'abc234',
  name: 'Test Odası',
  code: 'ABC-234',
  hostId: 'host',
  targetPlayerCount: playerCount,
  gameMode: mode,
  status: RoomStatus.playing,
  startsAtMs: 1000,
  questionSetId: '${mode.name}-v1',
  gameplayVersion: 'sync-v1',
  progress: progress,
  hints: hints,
  players: [
    const RoomPlayer(id: 'host', displayName: 'Yalın', isHost: true),
    const RoomPlayer(id: 'guest', displayName: 'Misafir'),
    for (var i = 2; i < playerCount; i++)
      RoomPlayer(id: 'player$i', displayName: 'Oyuncu $i'),
  ],
);

class FakeRoomService extends Fake implements FirebaseRoomService {
  final rooms = StreamController<GameRoom>.broadcast(sync: true);
  final offsets = StreamController<int>.broadcast(sync: true);
  final connections = StreamController<bool>.broadcast(sync: true);
  final saves = <GameProgress>[];
  final votes = <int>[];
  Future<void> Function(GameProgress)? onSave;
  Future<void> Function()? onHint;
  String uid = 'guest';
  GameRoom room = testRoom();
  int resultWrites = 0;
  @override
  String get currentUserId => uid;
  @override
  Stream<GameRoom> watchRoom(String roomId) => rooms.stream;
  @override
  Stream<int> watchServerTimeOffset() => offsets.stream;
  @override
  Stream<bool> watchConnection() => connections.stream;
  void publish(GameRoom next) {
    room = next;
    rooms.add(next);
  }

  @override
  Future<void> saveProgress(String roomId, GameProgress progress) async {
    saves.add(progress);
    await onSave?.call(progress);
    room = room.copyWith(progress: {...room.progress, currentUserId: progress});
  }

  @override
  Future<SharedHints?> requestHint(
    String roomId, {
    required int questionIndex,
    required int expectedRevealedCount,
    required int requiredVotes,
    required int letterCount,
  }) async {
    await onHint?.call();
    votes.add(questionIndex);
    final hints = room.hints[questionIndex] ?? const SharedHints();
    if (hints.revealedCount != expectedRevealedCount) return null;
    final next = hints.vote(
      currentUserId,
      requiredVotes: requiredVotes,
      letterCount: letterCount,
    );
    if (next != null) {
      publish(room.copyWith(hints: {...room.hints, questionIndex: next}));
    }
    return next;
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

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test(
    'Both clients receive shared letters from the Firebase list representation',
    () async {
      service.room = testRoom();
      cubit = GameCubit(service, service.room, nowMs: () => now);
      final otherService = FakeRoomService()..uid = 'host';
      final other = GameCubit(otherService, service.room, nowMs: () => now);
      try {
        connect();
        otherService.offsets.add(0);
        otherService.connections.add(true);
        await cubit.revealLetter();
        final raw = FirebaseRoomMapper.toMap(service.room)
          ..addAll({
            'hints': [cubit.state.hints.toMap(0)],
            'startsAtMs': 1000,
            'gameplayVersion': 'sync-v1',
            'questionSetId': 'quick-v1',
            'status': 'playing',
          });
        final remote = FirebaseRoomMapper.fromMap(service.room.id, raw);
        service.publish(remote);
        otherService.publish(remote);
        expect(cubit.state.hints.revealedCount, 1);
        expect(other.state.hints.revealedCount, 1);
        for (var i = 0; i < 4; i++) {
          expect(cubit.state.isRevealed(i), other.state.isRevealed(i));
        }
      } finally {
        await other.close();
        await otherService.disposeStreams();
      }
    },
  );

  test('Clock and connection gate actions; an answer waits on the same shared question', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    await cubit.submitAnswer('kapı');
    expect(service.saves, isEmpty);
    service.offsets.add(-500);
    service.connections.add(true);
    await cubit.submitAnswer('kapı');
    expect(service.saves, isEmpty);
    service.offsets.add(0);
    await cubit.submitAnswer('kapi');
    expect(cubit.state.progress.score, 400);
    expect(cubit.state.questionIndex, 0);
    expect(cubit.state.question!.answer, 'KAPI');
    expect(cubit.state.hasAnsweredCurrent, isTrue);
    await cubit.submitAnswer('kitap');
    expect(service.saves.length, 1);
    now = 26000;
    service.offsets.add(0);
    expect(cubit.state.questionIndex, 1);
    expect(cubit.state.question!.answer, 'KİTAP');
    expect(cubit.state.remainingSeconds, 25);
    expect(cubit.state.canAct, isTrue);
  });

  test('Repeated submit and optimistic failed writes do not resolve extra questions', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    connect();
    final pending = Completer<void>();
    service.onSave = (next) async {
      service.publish(testRoom(progress: {'guest': next}));
      await pending.future;
    };
    final answer = cubit.submitAnswer('kapı');
    await cubit.submitAnswer('kitap');
    expect(service.saves.length, 1);
    pending.completeError(StateError('permission-denied'));
    await answer;
    expect(cubit.state.progress, const GameProgress());
    expect(cubit.state.isSaving, isFalse);
  });

  test('A question timeout advances everyone but penalizes only unanswered players', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    connect();
    now = 26000;
    service.offsets.add(0);
    await flush();
    expect(cubit.state.progress.score, -400);
    expect(cubit.state.progress.lastOutcome, AnswerOutcome.timeout);
    expect(cubit.state.questionIndex, 1);
    expect(cubit.state.canAct, isTrue);
    await cubit.submitAnswer('kitap');
    now = 51000;
    service.offsets.add(0);
    await flush();
    expect(cubit.state.questionIndex, 2);
    expect(service.saves.length, 2);
    expect(cubit.state.progress.score, 100);
  });

  test(
    'Two-player hint is shared and reduces both players question value',
    () async {
      cubit = GameCubit(service, testRoom(), nowMs: () => now);
      connect();
      await cubit.revealLetter();
      expect(cubit.state.hints.revealedCount, 1);
      expect(cubit.state.questionValue, 300);
      expect(cubit.state.room.progress, isEmpty);
      await cubit.submitAnswer('kapı');
      expect(cubit.state.progress.score, 300);
    },
  );

  test('Rooms of 4 to 6 wait for a different player; votes reset after each letter', () async {
    service.room = testRoom(playerCount: 6);
    cubit = GameCubit(service, service.room, nowMs: () => now);
    connect();
    await cubit.revealLetter();
    expect(cubit.state.hints.revealedCount, 0);
    expect(cubit.state.hasVoted, isTrue);
    expect(cubit.state.questionValue, 400);
    await cubit.revealLetter();
    expect(service.votes.length, 1);
    final secondVote = cubit.state.hints.vote(
      'host',
      requiredVotes: 2,
      letterCount: 4,
    )!;
    service.publish(service.room.copyWith(hints: {0: secondVote}));
    expect(cubit.state.hints.revealedCount, 1);
    expect(cubit.state.questionValue, 300);
    expect(cubit.state.canVote, isTrue);
    await cubit.revealLetter();
    expect(cubit.state.hints.firstVoterId, 'guest');
    expect(cubit.state.hints.revealedCount, 1);
    now = 26000;
    service.offsets.add(0);
    await flush();
    expect(cubit.state.hints, const SharedHints());
  });

  test('Skipped questions catch up on reconnect and host is not needed for round transitions', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    connect();
    service.connections.add(false);
    now = 76000;
    service.offsets.add(0);
    expect(cubit.state.questionIndex, 3);
    expect(service.saves, isEmpty);
    service.connections.add(true);
    await flush();
    expect(cubit.state.progress.questionIndex, 3);
    expect(cubit.state.progress.score, -1500);
    expect(cubit.state.canAct, isTrue);
    now = 176000;
    service.offsets.add(0);
    await flush();
    expect(cubit.state.progress.finished, isTrue);
    expect(cubit.state.progress.score, -4900);
    expect(service.resultWrites, 1);
    service.publish(service.room.copyWith(status: RoomStatus.results));
    await cubit.submitAnswer('kapı');
    expect(service.saves.length, 7);
  });

  test('Final answer waits for its remaining question time; classic lasts 350 seconds', () async {
    const prior = GameProgress(
      questionIndex: 13,
      correctCount: 13,
      score: 8800,
      lastOutcome: AnswerOutcome.correct,
    );
    now = 326000;
    final room = testRoom(
      mode: RoomGameMode.classic,
      progress: {'guest': prior},
    );
    service.room = room;
    cubit = GameCubit(service, room, nowMs: () => now);
    connect();
    await cubit.submitAnswer('televizyon');
    expect(cubit.state.progress.score, 9800);
    expect(cubit.state.progress.finished, isTrue);
    expect(cubit.state.questionIndex, 13);
    expect(service.resultWrites, 0);
    now = 351000;
    service.offsets.add(0);
    await flush();
    expect(service.resultWrites, 1);
  });

  test('Late answer failure is rolled back before timeout and cannot leak the answer', () async {
    cubit = GameCubit(service, testRoom(), nowMs: () => now);
    connect();
    final pending = Completer<void>();
    service.onSave = (_) async {
      if (service.saves.length == 1) await pending.future;
    };
    final answer = cubit.submitAnswer('kapı');
    now = 26000;
    pending.completeError(StateError('deadline passed'));
    await answer;
    now += 3001;
    service.offsets.add(0);
    await flush();
    expect(cubit.state.progress.score, -400);
    expect(cubit.state.progress.correctCount, 0);
    expect(cubit.state.feedback, isNot(contains('KAPI')));
  });
}
