import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_feedback_cubit.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_mapper.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;

class HistoryRoomService extends FakeRoomService {
  final shown = <String>[];
  Future<void> Function()? onRecord;
  @override
  Future<void> recordQuestionShown(GameQuestion question) async {
    await onRecord?.call();
    shown.add(question.id!);
  }
}

GameRoom poolRoom() {
  final pool = jsonDecode(
    File('functions/content/examples.json').readAsStringSync(),
  ) as List;
  final questions = [for (var i = 0; i < pool.length; i += 6) pool[i]];
  final map = FirebaseRoomMapper.toMap(testRoom())
    ..addAll({
      'questionSetId': 'pool-v1:test',
      'questionEngine': 'pool-v1',
      'questions': questions,
      'status': 'playing',
      'gameplayVersion': 'sync-v1',
      'startsAtMs': 1000,
    });
  return FirebaseRoomMapper.fromMap('abc234', map);
}

void main() {
  test('pool snapshot maps stable IDs and shows a question only after local history commit', () async {
    final service = HistoryRoomService();
    final gate = Completer<void>();
    service.onRecord = () => gate.future;
    final cubit = GameCubit(service, poolRoom(), nowMs: () => 1000);
    addTearDown(() async {
      await cubit.close();
      await service.disposeStreams();
    });
    service.offsets.add(0);
    service.connections.add(true);
    expect(cubit.state.question, isNull);
    cubit.setForeground(true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.canAct, isFalse);
    expect(service.shown, isEmpty);
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.question!.id, 'example_1');
    expect(cubit.state.canAct, isTrue);
    service.offsets.add(0);
    service.offsets.add(0);
    expect(service.shown, ['example_1']);
  });

  test('background and skipped rounds are not seen; their answers are not revealed by feedback', () async {
    var now = 1000;
    final service = HistoryRoomService();
    final cubit = GameCubit(service, poolRoom(), nowMs: () => now);
    final feedback = GameFeedbackCubit(cubit);
    addTearDown(() async {
      await feedback.close();
      await cubit.close();
      await service.disposeStreams();
    });
    service.offsets.add(0);
    service.connections.add(true);
    now = 26001;
    service.offsets.add(0);
    await Future<void>.delayed(Duration.zero);
    expect(service.shown, isEmpty);
    expect(feedback.state, isNull);
    cubit.setForeground(true);
    await Future<void>.delayed(Duration.zero);
    expect(service.shown, ['example_7']);
    expect(cubit.state.question!.id, 'example_7');
  });

  test(
    'SQLite failure keeps unseen question hidden and supports retry',
    () async {
      var now = 1000;
      final service = HistoryRoomService()
        ..onRecord = () async {
          throw StateError('disk failure');
        };
      final cubit = GameCubit(service, poolRoom(), nowMs: () => now);
      addTearDown(() async {
        await cubit.close();
        await service.disposeStreams();
      });
      service.offsets.add(0);
      service.connections.add(true);
      cubit.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.question, isNull);
      expect(cubit.state.errorMessage, contains('cihazda'));
      service.onRecord = null;
      now += 3001;
      service.offsets.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.question!.id, 'example_1');
    },
  );
}
