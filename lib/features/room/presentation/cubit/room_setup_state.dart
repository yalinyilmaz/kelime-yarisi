import 'package:equatable/equatable.dart';

import '../../domain/entities/game_room.dart';
import '../../domain/entities/room_game_mode.dart';

enum RoomSetupFlow { create, join }

class RoomSetupState extends Equatable {
  const RoomSetupState({
    required this.flow,
    this.displayName = '',
    this.roomName = '',
    this.roomCode = '',
    this.targetPlayerCount = 5,
    this.gameMode = RoomGameMode.classic,
    this.errorMessage,
    this.errorCode,
    this.room,
    this.isSubmitting = false,
  });

  final RoomSetupFlow flow;
  final String displayName;
  final String roomName;
  final String roomCode;
  final int targetPlayerCount;
  final RoomGameMode gameMode;
  final String? errorMessage;
  final String? errorCode;
  final GameRoom? room;
  final bool isSubmitting;

  bool get canSubmit {
    if (displayName.trim().length < 2 || displayName.length > 24) return false;
    return switch (flow) {
      RoomSetupFlow.create =>
        roomName.trim().length >= 2 &&
            roomName.trim().length <= 40 &&
            targetPlayerCount >= 2 &&
            targetPlayerCount <= 6,
      RoomSetupFlow.join => roomCode.replaceAll('-', '').trim().length == 6,
    };
  }

  RoomSetupState copyWith({
    String? displayName,
    String? roomName,
    String? roomCode,
    int? targetPlayerCount,
    RoomGameMode? gameMode,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
    GameRoom? room,
    bool? isSubmitting,
  }) {
    return RoomSetupState(
      flow: flow,
      displayName: displayName ?? this.displayName,
      roomName: roomName ?? this.roomName,
      roomCode: roomCode ?? this.roomCode,
      targetPlayerCount: targetPlayerCount ?? this.targetPlayerCount,
      gameMode: gameMode ?? this.gameMode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      room: room ?? this.room,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [
    flow,
    displayName,
    roomName,
    roomCode,
    targetPlayerCount,
    gameMode,
    errorMessage,
    errorCode,
    room,
    isSubmitting,
  ];
}
