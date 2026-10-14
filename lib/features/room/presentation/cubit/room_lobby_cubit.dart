import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/firebase_room_service.dart';
import '../../domain/entities/game_room.dart';
import '../../domain/entities/room_player.dart';
import 'room_lobby_state.dart';

class RoomLobbyCubit extends Cubit<RoomLobbyState> {
  RoomLobbyCubit(this._roomService, GameRoom room)
    : super(RoomLobbyState(room: room)) {
    _roomSubscription = _roomService
        .watchRoom(room.id)
        .listen(_roomChanged, onError: _streamFailed);
    _offsetSubscription = _roomService.watchServerTimeOffset().listen(
      (offset) => emit(state.copyWith(serverTimeOffsetMs: offset)),
    );
    unawaited(_roomService.beginPresence(room.id));
  }

  final FirebaseRoomService _roomService;
  StreamSubscription<GameRoom>? _roomSubscription;
  StreamSubscription<int>? _offsetSubscription;
  Timer? _countdownTimer;
  bool _isStartingCountdown = false;
  bool _isMarkingPlaying = false;

  Future<void> toggleCurrentPlayerReady() async {
    RoomPlayer? currentPlayer;
    for (final player in state.room.players) {
      if (player.id == _roomService.currentUserId) {
        currentPlayer = player;
        break;
      }
    }
    if (currentPlayer == null || state.room.status != RoomStatus.lobby) return;

    try {
      await _roomService.setReady(
        state.room.id,
        isReady: !currentPlayer.isReady,
      );
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Hazır durumu güncellenemedi.'));
    }
  }

  Future<void> leaveRoom() async {
    if (state.isLeaving) return;
    emit(state.copyWith(isLeaving: true, clearError: true));
    try {
      await _roomService.leaveRoom(state.room.id);
    } catch (_) {
      emit(
        state.copyWith(
          isLeaving: false,
          errorMessage: 'Odadan çıkılamadı. Tekrar deneyin.',
        ),
      );
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  void _roomChanged(GameRoom room) {
    emit(state.copyWith(room: room, clearError: true));
    if (room.status == RoomStatus.countdown) {
      _startLocalTicker();
    } else {
      _countdownTimer?.cancel();
    }
    if (room.status == RoomStatus.playing ||
        room.status == RoomStatus.results) {
      // The game Cubit owns the room and clock subscriptions from this point on.
      unawaited(_roomSubscription?.cancel());
      unawaited(_offsetSubscription?.cancel());
      return;
    }

    final isHost = room.hostId == _roomService.currentUserId;
    if (isHost && room.status == RoomStatus.lobby && room.everyoneIsReady) {
      unawaited(_startCountdown());
    }
  }

  Future<void> _startCountdown() async {
    if (_isStartingCountdown) return;
    _isStartingCountdown = true;
    try {
      await _roomService.startCountdown(
        state.room.id,
        serverTimeOffsetMs: state.serverTimeOffsetMs,
        gameMode: state.room.gameMode,
      );
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Geri sayım başlatılamadı.'));
    } finally {
      _isStartingCountdown = false;
    }
  }

  void _startLocalTicker() {
    if (_countdownTimer?.isActive ?? false) return;
    _tickCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _tickCountdown(),
    );
  }

  void _tickCountdown() {
    if (isClosed) return;
    emit(state.copyWith(nowMs: DateTime.now().millisecondsSinceEpoch));
    final isHost = state.room.hostId == _roomService.currentUserId;
    if (isHost && state.countdownSeconds == 0 && !_isMarkingPlaying) {
      _isMarkingPlaying = true;
      unawaited(
        _roomService
            .markPlaying(state.room.id)
            .catchError((Object error) {
              if (!isClosed) {
                emit(
                  state.copyWith(
                    errorMessage: 'Oyun başlatılamadı. Tekrar deneniyor.',
                  ),
                );
              }
            })
            .whenComplete(() => _isMarkingPlaying = false),
      );
    }
  }

  void _streamFailed(Object error, StackTrace stackTrace) {
    if (isClosed || state.isLeaving) return;
    final message = error is RoomServiceException
        ? error.message
        : 'Oda bağlantısı kesildi.';
    emit(state.copyWith(errorMessage: message));
  }

  @override
  Future<void> close() async {
    _countdownTimer?.cancel();
    await _roomSubscription?.cancel();
    await _offsetSubscription?.cancel();
    return super.close();
  }
}
