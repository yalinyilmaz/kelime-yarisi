import 'package:equatable/equatable.dart';

import 'game_question.dart';

enum AnswerOutcome { correct, wrong, timeout }

class GameProgress extends Equatable {
  const GameProgress({
    this.questionIndex = 0,
    this.score = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.finished = false,
    this.lastOutcome,
  });

  // Number of resolved questions; the active question comes from the shared clock.
  final int questionIndex;
  final int score;
  final int correctCount;
  final int wrongCount;
  final bool finished;
  final AnswerOutcome? lastOutcome;

  GameProgress resolve(
    List<GameQuestion> questions, {
    required AnswerOutcome outcome,
    required int revealedCount,
  }) {
    if (finished || questionIndex >= questions.length) return this;
    final value =
        (questions[questionIndex].letterCount - revealedCount).clamp(1, 10) *
        100;
    final correct = outcome == AnswerOutcome.correct;
    final nextIndex = questionIndex + 1;
    return GameProgress(
      questionIndex: nextIndex,
      score: score + (correct ? value : -value),
      correctCount: correctCount + (correct ? 1 : 0),
      wrongCount: wrongCount + (correct ? 0 : 1),
      finished: nextIndex == questions.length,
      lastOutcome: outcome,
    );
  }

  Map<String, Object?> toMap() => {
    'questionIndex': questionIndex,
    'score': score,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
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
      finished: map['finished'] as bool? ?? false,
      lastOutcome: outcome == null
          ? null
          : AnswerOutcome.values.byName(outcome),
    );
  }

  @override
  List<Object?> get props => [
    questionIndex,
    score,
    correctCount,
    wrongCount,
    finished,
    lastOutcome,
  ];
}
