import 'package:equatable/equatable.dart';

import '../../../room/domain/entities/game_room.dart';
import '../../domain/game_progress.dart';
import '../../domain/game_question.dart';

class GameState extends Equatable {
  const GameState({
    required this.room,
    required this.questions,
    required this.progress,
    this.serverNowMs = 0,
    this.clockReady = false,
    this.isConnected = false,
    this.isSaving = false,
    this.isLeaving = false,
    this.feedback,
    this.errorMessage,
  });

  final GameRoom room;
  final List<GameQuestion> questions;
  final GameProgress progress;
  final int serverNowMs;
  final bool clockReady;
  final bool isConnected;
  final bool isSaving;
  final bool isLeaving;
  final String? feedback;
  final String? errorMessage;

  int get remainingSeconds => !clockReady || room.endsAtMs == null
      ? room.gameMode.duration.inSeconds
      : ((room.endsAtMs! - serverNowMs) / 1000).ceil().clamp(
          0,
          room.gameMode.duration.inSeconds,
        );

  bool get hasExpired =>
      clockReady && room.endsAtMs != null && serverNowMs >= room.endsAtMs!;

  GameQuestion? get question =>
      progress.finished || progress.questionIndex >= questions.length
      ? null
      : questions[progress.questionIndex];

  bool get canAct =>
      clockReady &&
      isConnected &&
      !isSaving &&
      !isLeaving &&
      !hasExpired &&
      room.status == RoomStatus.playing &&
      serverNowMs >= (room.startsAtMs ?? serverNowMs + 1) &&
      question != null;

  GameState copyWith({
    GameRoom? room,
    GameProgress? progress,
    int? serverNowMs,
    bool? clockReady,
    bool? isConnected,
    bool? isSaving,
    bool? isLeaving,
    String? feedback,
    String? errorMessage,
    bool clearError = false,
  }) => GameState(
    room: room ?? this.room,
    questions: questions,
    progress: progress ?? this.progress,
    serverNowMs: serverNowMs ?? this.serverNowMs,
    clockReady: clockReady ?? this.clockReady,
    isConnected: isConnected ?? this.isConnected,
    isSaving: isSaving ?? this.isSaving,
    isLeaving: isLeaving ?? this.isLeaving,
    feedback: feedback ?? this.feedback,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    room,
    questions,
    progress,
    serverNowMs,
    clockReady,
    isConnected,
    isSaving,
    isLeaving,
    feedback,
    errorMessage,
  ];
}
