import 'package:equatable/equatable.dart';

import 'game_question.dart';

enum AnswerOutcome { correct, wrong, timeout, beaten }

class GameProgress extends Equatable {
  const GameProgress({
    this.questionIndex = 0,
    this.score = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.skippedCount = 0,
    this.finished = false,
    this.lastOutcome,
    this.lastScoreDelta,
  });

  // Number of resolved questions; the active question comes from the shared clock.
  final int questionIndex;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final bool finished;
  final AnswerOutcome? lastOutcome;
  final int? lastScoreDelta;

  GameProgress resolve(
    List<GameQuestion> questions, {
    required AnswerOutcome outcome,
    required int revealedCount,
    bool penalizeIncorrect = true,
  }) {
    if (finished || questionIndex >= questions.length) return this;
    final value =
        (questions[questionIndex].letterCount - revealedCount).clamp(1, 10) *
        100;
    final correct = outcome == AnswerOutcome.correct;
    final nextIndex = questionIndex + 1;
    return GameProgress(
      questionIndex: nextIndex,
      score:
          score +
          (correct
              ? value
              : outcome == AnswerOutcome.beaten || !penalizeIncorrect
              ? 0
              : -value),
      correctCount: correctCount + (correct ? 1 : 0),
      wrongCount:
          wrongCount + (correct || outcome == AnswerOutcome.beaten ? 0 : 1),
      skippedCount: skippedCount + (outcome == AnswerOutcome.beaten ? 1 : 0),
      finished: nextIndex == questions.length,
      lastOutcome: outcome,
    );
  }

  Map<String, Object?> toMap() => {
    'questionIndex': questionIndex,
    'score': score,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    if (skippedCount > 0) 'skippedCount': skippedCount,
    'finished': finished,
    'lastOutcome': lastOutcome?.name,
    'updatedAtMs': {'.sv': 'timestamp'},
  };

  static GameProgress fromMap(Object? value) {
    final map = value is Map ? value : const {};
    final outcome = map['lastOutcome'] as String?;
    return GameProgress(
      questionIndex: (map['questionIndex'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (map['wrongCount'] as num?)?.toInt() ?? 0,
      skippedCount: (map['skippedCount'] as num?)?.toInt() ?? 0,
      finished: map['finished'] as bool? ?? false,
      lastOutcome: outcome == null
          ? null
          : AnswerOutcome.values.byName(outcome),
      lastScoreDelta: (map['lastScoreDelta'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
    questionIndex,
    score,
    correctCount,
    wrongCount,
    skippedCount,
    finished,
    lastOutcome,
    lastScoreDelta,
  ];
}
