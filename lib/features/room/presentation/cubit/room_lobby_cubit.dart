import '../../../../core/monitoring/error_reporter.dart';
import '../../../../core/config/room_invitation.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../game/domain/question_capacity.dart';
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
    _offsetSubscription = _roomService.watchServerTimeOffset().listen((offset) {
      if (!isClosed) emit(state.copyWith(serverTimeOffsetMs: offset));
    }, onError: _streamFailed);
    unawaited(
      _roomService.beginPresence(room.id).catchError((
        Object error,
        StackTrace stack,
      ) {
        _streamFailed(error, stack);
      }),
    );
    if (room.questionEngine == 'pool-v1') unawaited(loadQuestionCapacity());
  }

  final FirebaseRoomService _roomService;
  StreamSubscription<GameRoom>? _roomSubscription;
  StreamSubscription<int>? _offsetSubscription;
  Timer? _countdownTimer;
  bool _isMarkingPlaying = false;
  bool _isSharingCode = false;

  Future<void> copyAndShareCode(Rect origin) async {
    if (isClosed || state.isLeaving || _isSharingCode) return;
    _isSharingCode = true;
    var copied = false;
    try {
      final code = state.room.code;
      await Clipboard.setData(ClipboardData(text: code));
      copied = true;
      if (isClosed || state.isLeaving) return;
      await SharePlus.instance.share(
        ShareParams(
          text: RoomInvitation.shareText(code),
          sharePositionOrigin: origin,
        ),
      );
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'lobby.copy_and_share_code',
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage: copied
                ? 'Oda kodu kopyalandı; paylaşım menüsü açılamadı.'
                : 'Oda kodu kopyalanamadı. Tekrar dene.',
          ),
        );
      }
    } finally {
      _isSharingCode = false;
    }
  }

  Future<void> loadQuestionCapacity() async {
    if (isClosed || state.isLoadingQuestionCapacity) return;
    emit(state.copyWith(isLoadingQuestionCapacity: true));
    try {
      final report = await _roomService.prepareQuestionHistory(state.room.id);
      if (!isClosed) {
        emit(
          state.copyWith(questionCapacity: QuestionCapacity.fromMap(report)),
        );
      }
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'room_lobby_cubit.loadQuestionCapacity',
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage: error is RoomServiceException
                ? error.message
                : 'Soru havuzu bilgisi alınamadı.',
          ),
        );
      }
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isLoadingQuestionCapacity: false));
      }
    }
  }

  bool get canStartGame =>
      !isClosed &&
      !state.isLeaving &&
      !state.isStartingGame &&
      state.room.canStart(
        playerId: _roomService.currentUserId,
        allowSolo: kDebugMode,
      );

  Future<void> toggleCurrentPlayerReady() async {
    if (isClosed || state.isLeaving) return;
    RoomPlayer? currentPlayer;
    for (final player in state.room.players) {
      if (player.id == _roomService.currentUserId) {
        currentPlayer = player;
        break;
      }
    }
    if (currentPlayer == null ||
        state.room.status != RoomStatus.lobby ||
        state.isStartingGame) {
      return;
    }

    try {
      await _roomService.setReady(
        state.room.id,
        isReady: !currentPlayer.isReady,
      );
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'room_lobby_cubit.toggleCurrentPlayerReady',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          errorMessage: error is RoomServiceException
              ? error.message
              : 'Hazır durumu güncellenemedi.',
        ),
      );
    }
  }

  Future<void> leaveRoom() async {
    if (isClosed || state.isLeaving) return;
    emit(state.copyWith(isLeaving: true, clearError: true));
    try {
      await _roomService.leaveRoom(state.room.id);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'room_lobby_cubit.leaveRoom',
      );
      if (isClosed) return;
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
    if (isClosed || state.isLeaving) return;
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
  }

  Future<void> startGame() async {
    if (!canStartGame) return;
    emit(state.copyWith(isStartingGame: true, clearError: true));
    try {
      await _roomService.startCountdown(
        state.room.id,
        serverTimeOffsetMs: state.serverTimeOffsetMs,
        gameMode: state.room.gameMode,
        questionEngine: state.room.questionEngine,
      );
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'room_lobby_cubit.startGame',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          errorMessage: error is RoomServiceException
              ? error.message
              : 'Geri sayım başlatılamadı.',
          questionCapacity: error is RoomServiceException
              ? error.capacity
              : null,
          collectiveCapacity:
              error is RoomServiceException && error.capacity != null,
        ),
      );
    } finally {
      if (!isClosed) emit(state.copyWith(isStartingGame: false));
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
    if ((isHost || state.room.isRace) &&
        state.countdownSeconds == 0 &&
        !_isMarkingPlaying) {
      _isMarkingPlaying = true;
      unawaited(
        _roomService
            .markPlaying(state.room.id)
            .catchError((Object error, StackTrace stackTrace) {
              ErrorReporter.report(
                error,
                stackTrace,
                operation: 'room_lobby_cubit._tickCountdown',
              );
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
    ErrorReporter.report(error, stackTrace, operation: 'lobby.stream');
    if (isClosed || state.isLeaving) return;
    final message = error is RoomServiceException
        ? error.message
        : 'Oda bağlantısı kesildi.';
    emit(state.copyWith(errorMessage: message));
  }

  @override
  Future<void> close() async {
    _countdownTimer?.cancel();
    await Future.wait([
      if (_roomSubscription != null) _roomSubscription!.cancel(),
      if (_offsetSubscription != null) _offsetSubscription!.cancel(),
      super.close(),
    ]);
  }
}
