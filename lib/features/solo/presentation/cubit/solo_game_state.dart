import 'package:equatable/equatable.dart';

import '../../../game/domain/game_answer_feedback.dart';
import '../../../game/domain/game_progress.dart';
import '../../../game/domain/game_question.dart';
import '../../../game/domain/game_question_set.dart';
import '../../../game/domain/shared_hints.dart';

enum SoloGamePhase { idle, loading, playing, completed, expired, failed }

class SoloGameState extends Equatable {
  const SoloGameState({
    this.phase = SoloGamePhase.idle,
    this.set,
    this.progress = const GameProgress(),
    this.remainingSeconds = 260,
    this.revealedCount = 0,
    this.hintUsage = const {},
    this.feedback,
    this.errorMessage,
    this.soundEnabled = true,
    this.isSavingCompletion = false,
    this.completionSaved = false,
    this.isLeaving = false,
  });

  static const duration = Duration(minutes: 4, seconds: 20);
  final SoloGamePhase phase;
  final GameQuestionSet? set;
  final GameProgress progress;
  final int remainingSeconds;
  final int revealedCount;
  final Map<int, int> hintUsage;
  final GameAnswerFeedback? feedback;
  final String? errorMessage;
  final bool soundEnabled;
  final bool isSavingCompletion;
  final bool completionSaved;
  final bool isLeaving;

  int get questionIndex => feedback?.questionIndex ?? progress.questionIndex;
  GameQuestion? get question =>
      set != null && questionIndex < set!.questions.length
      ? set!.questions[questionIndex]
      : null;
  int get questionValue => ((question?.letterCount ?? 0) - revealedCount) * 100;
  int get currentHintCount => hintUsage[questionIndex] ?? 0;
  int get remainingHints =>
      10 - hintUsage.values.fold(0, (sum, count) => sum + count);
  List<String> get visibleHints =>
      question?.hints.take(currentHintCount).toList() ?? const [];
  int get revealedMask => question == null
      ? 0
      : SharedHints(revealedCount: revealedCount)
            .revealedMask(set!.id, questionIndex, question!.letterCount);
  bool get canAct =>
      phase == SoloGamePhase.playing &&
      !isLeaving &&
      feedback == null &&
      !progress.finished &&
      remainingSeconds > 0;
  bool get canRevealLetter =>
      canAct && revealedCount < question!.letterCount - 1;
  bool get canRequestHint =>
      canAct && currentHintCount < 2 && remainingHints > 0;

  SoloGameState copyWith({
    SoloGamePhase? phase,
    GameQuestionSet? set,
    GameProgress? progress,
    int? remainingSeconds,
    int? revealedCount,
    Map<int, int>? hintUsage,
    GameAnswerFeedback? feedback,
    bool clearFeedback = false,
    String? errorMessage,
    bool clearError = false,
    bool? soundEnabled,
    bool? isSavingCompletion,
    bool? completionSaved,
    bool? isLeaving,
  }) => SoloGameState(
    phase: phase ?? this.phase,
    set: set ?? this.set,
    progress: progress ?? this.progress,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    revealedCount: revealedCount ?? this.revealedCount,
    hintUsage: hintUsage ?? this.hintUsage,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    isSavingCompletion: isSavingCompletion ?? this.isSavingCompletion,
    completionSaved: completionSaved ?? this.completionSaved,
    isLeaving: isLeaving ?? this.isLeaving,
  );

  @override
  List<Object?> get props => [
    phase,
    set,
    progress,
    remainingSeconds,
    revealedCount,
    hintUsage,
    feedback,
    errorMessage,
    soundEnabled,
    isSavingCompletion,
    completionSaved,
    isLeaving,
  ];
}
