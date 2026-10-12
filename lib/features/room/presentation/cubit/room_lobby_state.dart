import 'package:equatable/equatable.dart';

import '../../domain/entities/game_room.dart';

class RoomLobbyState extends Equatable {
  const RoomLobbyState({
    required this.room,
    this.serverTimeOffsetMs = 0,
    this.nowMs = 0,
    this.isLeaving = false,
    this.errorMessage,
  });

  final GameRoom room;
  final int serverTimeOffsetMs;
  final int nowMs;
  final bool isLeaving;
  final String? errorMessage;

  int get serverNowMs =>
      (nowMs == 0 ? DateTime.now().millisecondsSinceEpoch : nowMs) +
      serverTimeOffsetMs;

  int? get countdownSeconds {
    final startsAtMs = room.startsAtMs;
    if (startsAtMs == null || room.status != RoomStatus.countdown) return null;
    final remainingMs = startsAtMs - serverNowMs;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  RoomLobbyState copyWith({
    GameRoom? room,
    int? serverTimeOffsetMs,
    int? nowMs,
    bool? isLeaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RoomLobbyState(
      room: room ?? this.room,
      serverTimeOffsetMs: serverTimeOffsetMs ?? this.serverTimeOffsetMs,
      nowMs: nowMs ?? this.nowMs,
      isLeaving: isLeaving ?? this.isLeaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    room,
    serverTimeOffsetMs,
    nowMs,
    isLeaving,
    errorMessage,
  ];
}
