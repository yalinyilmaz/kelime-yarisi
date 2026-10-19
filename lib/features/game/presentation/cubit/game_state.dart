import 'package:equatable/equatable.dart';

import '../../../room/domain/entities/game_room.dart';
import '../../../room/domain/entities/room_player.dart';
import '../../../room/domain/entities/room_game_mode.dart';
import '../../domain/game_progress.dart';
import '../../domain/game_answer_feedback.dart';
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
    this.isRequestingClueHint = false,
    this.currentUserId = '',
    this.isLeaving = false,
    this.feedback,
    this.errorMessage,
    this.answerFeedback,
    this.recordedQuestionIndices = const {},
  });

  final GameRoom room;
  final List<GameQuestion> questions;
  final GameProgress progress;
  final int serverNowMs;
  final bool clockReady;
  final bool isConnected;
  final bool isSaving;
  final bool isVoting;
  final bool isRequestingClueHint;
  final String currentUserId;
  final bool isLeaving;
  final String? feedback;
  final String? errorMessage;
  final GameAnswerFeedback? answerFeedback;
  final Set<int> recordedQuestionIndices;
  bool get isHistoryReady =>
      !room.usesQuestionPool || recordedQuestionIndices.contains(questionIndex);

  int get questionIndex => room.isRace
      ? room.race?.questionIndex ?? 0
      : !clockReady || room.startsAtMs == null
      ? 0
      : ((serverNowMs - room.startsAtMs!) ~/
                RoomGameMode.questionDuration.inMilliseconds)
            .clamp(0, questions.length);

  int get remainingSeconds => room.isRace
      ? !clockReady || room.race == null || room.race!.isResolved
            ? 0
            : ((room.race!.startedAtMs + 25000 - serverNowMs) / 1000)
                  .ceil()
                  .clamp(0, 25)
      : !clockReady || room.startsAtMs == null
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
  Map<int, int> get clueHintUsage =>
      room.clueHintUsage[currentUserId] ?? const {};
  int get currentClueHintCount => clueHintUsage[questionIndex] ?? 0;
  int get remainingClueHints =>
      (10 - clueHintUsage.values.fold<int>(0, (sum, count) => sum + count))
          .clamp(0, 10)
          .toInt();
  List<String> get visibleClueHints =>
      question?.hints.take(currentClueHintCount).toList(growable: false) ??
      const [];
  bool get canRequestClueHint =>
      room.isRace &&
      canAct &&
      question!.hints.length == 2 &&
      currentClueHintCount < 2 &&
      remainingClueHints > 0;
  bool isRevealed(int index) =>
      question != null &&
      (hints.revealedMask(room.id, questionIndex, question!.letterCount) &
              (1 << index)) !=
          0;

  bool get hasExpired => room.isRace
      ? questionIndex >= questions.length || room.status == RoomStatus.results
      : clockReady && room.endsAtMs != null && serverNowMs >= room.endsAtMs!;

  GameQuestion? get question =>
      questionIndex >= questions.length || !isHistoryReady
      ? null
      : questions[questionIndex];

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
      (room.isRace
          ? room.race != null &&
                !room.race!.isResolved &&
                serverNowMs >= room.race!.startedAtMs &&
                remainingSeconds > 0
          : room.gameplayVersion == 'sync-v1') &&
      question != null;

  bool get canAct => canEditAnswer && !isVoting && !isRequestingClueHint;

  bool get isHost => room.hostId == currentUserId;

  List<({RoomPlayer player, GameProgress progress, int rank})> get standings {
    GameProgress progressFor(String id) => id == currentUserId
        ? progress
        : room.progress[id] ?? const GameProgress();
    final players = [...room.players]
      ..sort((a, b) {
        final order = progressFor(b.id).score
            .compareTo(progressFor(a.id).score);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    return [
      for (final player in players)
        (
          player: player,
          progress: progressFor(player.id),
          rank:
              1 +
              players
                  .where(
                    (other) =>
                        progressFor(other.id).score >
                        progressFor(player.id).score,
                  )
                  .length,
        ),
    ];
  }

  GameState copyWith({
    GameRoom? room,
    GameProgress? progress,
    int? serverNowMs,
    bool? clockReady,
    bool? isConnected,
    bool? isSaving,
    bool? isVoting,
    bool? isRequestingClueHint,
    bool? isLeaving,
    String? feedback,
    String? errorMessage,
    GameAnswerFeedback? answerFeedback,
    Set<int>? recordedQuestionIndices,
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
    isRequestingClueHint: isRequestingClueHint ?? this.isRequestingClueHint,
    currentUserId: currentUserId,
    isLeaving: isLeaving ?? this.isLeaving,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    answerFeedback: answerFeedback ?? this.answerFeedback,
    recordedQuestionIndices:
        recordedQuestionIndices ?? this.recordedQuestionIndices,
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
    isRequestingClueHint,
    currentUserId,
    isLeaving,
    feedback,
    errorMessage,
    answerFeedback,
    recordedQuestionIndices,
  ];
}
