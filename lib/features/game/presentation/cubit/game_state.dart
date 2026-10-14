import 'package:equatable/equatable.dart';

import '../../../room/domain/entities/game_room.dart';
import '../../../room/domain/entities/room_game_mode.dart';
import '../../domain/game_progress.dart';
import '../../domain/game_question.dart';
import '../../domain/shared_hints.dart';

class GameState extends Equatable {
  const GameState({
    required this.room,
    required this.questions,
    required this.progress,
    this.serverNowMs = 0,
    this.clockReady = false,
    this.isConnected = false,
    this.isSaving = false,
    this.isVoting = false,
    this.currentUserId = '',
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
  final bool isVoting;
  final String currentUserId;
  final bool isLeaving;
  final String? feedback;
  final String? errorMessage;

  int get questionIndex => !clockReady || room.startsAtMs == null
      ? 0
      : ((serverNowMs - room.startsAtMs!) ~/
                RoomGameMode.questionDuration.inMilliseconds)
            .clamp(0, questions.length);

  int get remainingSeconds => !clockReady || room.startsAtMs == null
      ? 25
      : hasExpired
      ? 0
      : ((room.startsAtMs! +
                    (questionIndex + 1) *
                        RoomGameMode.questionDuration.inMilliseconds -
                    serverNowMs) /
                1000)
            .ceil()
            .clamp(0, 25);

  SharedHints get hints => room.hints[questionIndex] ?? const SharedHints();
  int get questionValue => question == null
      ? 0
      : (question!.letterCount - hints.revealedCount) * 100;
  bool get hasAnsweredCurrent => progress.questionIndex > questionIndex;
  bool get hasVoted => hints.firstVoterId == currentUserId;
  bool get canVote => canAct && !hasVoted && questionValue > 100;
  bool isRevealed(int index) =>
      question != null &&
      (hints.revealedMask(room.id, questionIndex, question!.letterCount) &
              (1 << index)) !=
          0;

  bool get hasExpired =>
      clockReady && room.endsAtMs != null && serverNowMs >= room.endsAtMs!;

  GameQuestion? get question =>
      questionIndex >= questions.length ? null : questions[questionIndex];

  // Voting must not detach the keyboard's input connection.
  bool get canEditAnswer =>
      clockReady &&
      isConnected &&
      !isSaving &&
      !isLeaving &&
      !hasExpired &&
      room.status == RoomStatus.playing &&
      serverNowMs >= (room.startsAtMs ?? serverNowMs + 1) &&
      progress.questionIndex == questionIndex &&
      room.gameplayVersion == 'sync-v1' &&
      question != null;

  bool get canAct => canEditAnswer && !isVoting;

  GameState copyWith({
    GameRoom? room,
    GameProgress? progress,
    int? serverNowMs,
    bool? clockReady,
    bool? isConnected,
    bool? isSaving,
    bool? isVoting,
    bool? isLeaving,
    String? feedback,
    String? errorMessage,
    bool clearError = false,
    bool clearFeedback = false,
  }) => GameState(
    room: room ?? this.room,
    questions: questions,
    progress: progress ?? this.progress,
    serverNowMs: serverNowMs ?? this.serverNowMs,
    clockReady: clockReady ?? this.clockReady,
    isConnected: isConnected ?? this.isConnected,
    isSaving: isSaving ?? this.isSaving,
    isVoting: isVoting ?? this.isVoting,
    currentUserId: currentUserId,
    isLeaving: isLeaving ?? this.isLeaving,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
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
    isVoting,
    currentUserId,
    isLeaving,
    feedback,
    errorMessage,
  ];
}
