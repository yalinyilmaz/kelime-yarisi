import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_mapper.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;

class HistoryRoomService extends FakeRoomService {
  final completed = <String>[];
  Future<void> Function()? onRecord;
  @override
  Future<void> recordCompletedSet(String setId) async {
    await onRecord?.call();
    completed.add(setId);
  }

  @override
  Future<void> leaveRoom(String roomId) async {}
}

GameRoom poolRoom() {
  final pool = jsonDecode(
    File('functions/content/examples.json').readAsStringSync(),
  ) as List;
  final questions = [
    for (var length = 4; length <= 10; length++)
      ...pool.where((q) => q['letterCount'] == length).take(2),
  ];
  final map = FirebaseRoomMapper.toMap(testRoom(mode: RoomGameMode.classic))
    ..addAll({
      'questionSetId': 'pool-v1:session',
      'contentSetId': 'initial_001',
      'questionEngine': 'pool-v1',
      'questions': questions,
      'status': 'playing',
      'gameplayVersion': 'sync-v1',
      'startsAtMs': 1000,
    });
  return FirebaseRoomMapper.fromMap('abc234', map);
}

void main() {
  test('leaving after four questions does not consume the set', () async {
    var now = 1000;
    final service = HistoryRoomService();
    final cubit = GameCubit(service, poolRoom(), nowMs: () => now);
    addTearDown(() async {
      await cubit.close();
      await service.disposeStreams();
    });
    service.offsets.add(0);
    service.connections.add(true);
    cubit.setForeground(true);
    expect(cubit.state.question, isNotNull);
    for (var i = 0; i < 4; i++) {
      now = 1000 + i * 25000;
      service.offsets.add(0);
      await cubit.submitAnswer(cubit.state.question!.answer);
    }
    await cubit.leaveRoom();
    expect(service.completed, isEmpty);
    expect(cubit.state.recordedQuestionIndices, hasLength(4));
  });

  for (final diskFailure in [false, true]) {
    test(
      'fourteen answers commit the whole set once; disk failure retries: $diskFailure',
      () async {
        var now = 1000;
        final service = HistoryRoomService();
        if (diskFailure) {
          service.onRecord = () async {
            throw StateError('disk failure');
          };
        }
        final cubit = GameCubit(service, poolRoom(), nowMs: () => now);
        addTearDown(() async {
          await cubit.close();
          await service.disposeStreams();
        });
        service.offsets.add(0);
        service.connections.add(true);
        cubit.setForeground(true);
        for (var i = 0; i < 14; i++) {
          now = 1000 + i * 25000;
          service.offsets.add(0);
          expect(service.completed, isEmpty);
          await cubit.submitAnswer(cubit.state.question!.answer);
        }
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.progress.finished, isTrue);
        if (diskFailure) {
          expect(service.completed, isEmpty);
          expect(cubit.state.errorMessage, contains('set cihazda'));
          service.onRecord = null;
          now += 3001;
          service.offsets.add(0);
          await Future<void>.delayed(Duration.zero);
        }
        expect(service.completed, ['initial_001']);
        service.offsets.add(0);
        service.offsets.add(0);
        await cubit.leaveRoom();
        expect(service.completed, ['initial_001']);
      },
    );
  }
}
