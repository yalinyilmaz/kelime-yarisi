import 'package:equatable/equatable.dart';

import '../../domain/entities/game_room.dart';
import '../../../game/domain/question_capacity.dart';

class RoomLobbyState extends Equatable {
  const RoomLobbyState({
    required this.room,
    this.serverTimeOffsetMs = 0,
    this.nowMs = 0,
    this.isLeaving = false,
    this.isStartingGame = false,
    this.errorMessage,
    this.questionCapacity,
    this.isLoadingQuestionCapacity = false,
    this.collectiveCapacity = false,
  });

  final GameRoom room;
  final int serverTimeOffsetMs;
  final int nowMs;
  final bool isLeaving;
  final bool isStartingGame;
  final String? errorMessage;
  final QuestionCapacity? questionCapacity;
  final bool isLoadingQuestionCapacity;
  final bool collectiveCapacity;

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
    bool? isStartingGame,
    String? errorMessage,
    bool clearError = false,
    QuestionCapacity? questionCapacity,
    bool? isLoadingQuestionCapacity,
    bool? collectiveCapacity,
  }) {
    return RoomLobbyState(
      room: room ?? this.room,
      serverTimeOffsetMs: serverTimeOffsetMs ?? this.serverTimeOffsetMs,
      nowMs: nowMs ?? this.nowMs,
      isLeaving: isLeaving ?? this.isLeaving,
      isStartingGame: isStartingGame ?? this.isStartingGame,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      questionCapacity: questionCapacity ?? this.questionCapacity,
      isLoadingQuestionCapacity:
          isLoadingQuestionCapacity ?? this.isLoadingQuestionCapacity,
      collectiveCapacity: collectiveCapacity ?? this.collectiveCapacity,
    );
  }

  @override
  List<Object?> get props => [
    room,
    serverTimeOffsetMs,
    nowMs,
    isLeaving,
    isStartingGame,
    errorMessage,
    questionCapacity,
    isLoadingQuestionCapacity,
    collectiveCapacity,
  ];
}
