import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/app/app.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_audio_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_feedback_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_state.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';
import 'package:kelime_yarisi/features/room/presentation/cubit/room_lobby_cubit.dart';
import 'package:kelime_yarisi/features/room/presentation/cubit/room_setup_cubit.dart';
import 'package:kelime_yarisi/features/room/presentation/cubit/room_setup_state.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;
import 'game_page_test.dart' show FakeGameSounds;

void main() {
  test(
    'audio detaches from game even while native sound disposal is waiting',
    () async {
      final game = _EventGame();
      final sounds = _SlowSounds();
      final audio = GameAudioCubit(game, sounds: sounds);
      expect(game.events.hasListener, isTrue);
      final closing = audio.close();
      expect(audio.isClosed, isTrue);
      expect(game.events.hasListener, isFalse);
      sounds.disposal.complete();
      await closing;
      await game.events.close();
    },
  );

  test('feedback releases its game subscription when removed', () async {
    final game = _EventGame();
    final feedback = GameFeedbackCubit(game);
    expect(game.events.hasListener, isTrue);
    await feedback.close();
    expect(game.events.hasListener, isFalse);
    await game.events.close();
  });

  test(
    'game closes every input stream immediately while one cancellation is slow',
    () async {
      final service = _SlowService();
      final game = GameCubit(service, testRoom());
      expect(service.offsets.hasListener, isTrue);
      expect(service.connections.hasListener, isTrue);
      final closing = game.close();
      expect(game.isClosed, isTrue);
      expect(service.offsets.hasListener, isFalse);
      expect(service.connections.hasListener, isFalse);
      service.offsets.add(10);
      service.connections.add(true);
      service.cancelGate.complete();
      await closing;
      await service.slowRooms.close();
      await service.disposeStreams();
    },
  );

  test(
    'lobby releases clock subscription even while room cancellation is slow',
    () async {
      final service = _SlowService();
      final lobby = RoomLobbyCubit(
        service,
        testRoom().copyWith(status: RoomStatus.lobby),
      );
      final closing = lobby.close();
      expect(lobby.isClosed, isTrue);
      expect(service.offsets.hasListener, isFalse);
      service.offsets.add(10);
      service.cancelGate.complete();
      await closing;
      await service.slowRooms.close();
      await service.disposeStreams();
    },
  );

  test(
    'game transition releases lobby subscriptions before its page is disposed',
    () async {
      final service = _PendingService();
      final lobby = RoomLobbyCubit(
        service,
        testRoom().copyWith(status: RoomStatus.lobby),
      );
      expect(service.rooms.hasListener, isTrue);
      service.publish(testRoom());
      expect(service.rooms.hasListener, isFalse);
      expect(service.offsets.hasListener, isFalse);
      await lobby.close();
      await service.disposeStreams();
    },
  );

  for (final flow in RoomSetupFlow.values) {
    test(
      'leaving $flow before create/join completes cleans the late room',
      () async {
        final service = _PendingService();
        final setup = RoomSetupCubit(service, flow: flow);
        setup.displayNameChanged('Oyuncu');
        setup.roomNameChanged('Test');
        setup.roomCodeChanged('ABC234');
        final submitting = setup.submit();
        await setup.close();
        service.roomGate.complete(testRoom());
        await submitting;
        expect(service.leftRooms, ['abc234']);
        await service.disposeStreams();
      },
    );
  }

  test(
    'late ready failure after lobby closure never emits on a closed Cubit',
    () async {
      final service = _PendingService();
      final lobby = RoomLobbyCubit(
        service,
        testRoom().copyWith(status: RoomStatus.lobby),
      );
      final ready = lobby.toggleCurrentPlayerReady();
      await lobby.close();
      service.readyGate.completeError(
        StateError('network failed after navigation'),
      );
      await ready;
      await service.disposeStreams();
    },
  );

  testWidgets(
    'app owner disposes its room service when the widget tree is removed',
    (tester) async {
      final service = _PendingService();
      await tester.pumpWidget(KelimeYarisiApp(roomService: service));
      await tester.tap(find.text('Çok Oyunculu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oda Oluştur'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(service.disposals, 1);
      expect(tester.takeException(), isNull);
      await service.disposeStreams();
    },
  );
}

class _PendingService extends FakeRoomService {
  final roomGate = Completer<GameRoom>();
  final readyGate = Completer<void>();
  final leftRooms = <String>[];
  int disposals = 0;
  @override
  Future<void> beginPresence(String roomId) async {}
  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    leftRooms.add(roomId);
  }

  @override
  Future<GameRoom> createRoom({
    required String displayName,
    required String roomName,
    required int targetPlayerCount,
    required RoomGameMode gameMode,
  }) => roomGate.future;
  @override
  Future<GameRoom> joinRoom({
    required String displayName,
    required String roomCode,
  }) => roomGate.future;
  @override
  Future<void> setReady(String roomId, {required bool isReady}) =>
      readyGate.future;
}

class _SlowService extends _PendingService {
  final cancelGate = Completer<void>();
  late final slowRooms = StreamController<GameRoom>(
    sync: true,
    onCancel: () => cancelGate.future,
  );
  @override
  Stream<GameRoom> watchRoom(String roomId) => slowRooms.stream;
}

class _EventGame extends Fake implements GameCubit {
  final events = StreamController<GameState>.broadcast(sync: true);
  @override
  GameState get state => GameState(
    room: testRoom(),
    questions: const [],
    progress: const GameProgress(),
  );
  @override
  Stream<GameState> get stream => events.stream;
}

class _SlowSounds extends FakeGameSounds {
  final disposal = Completer<void>();
  @override
  Future<void> dispose() => disposal.future;
}
