import 'dart:math';

import 'package:equatable/equatable.dart';

import 'game_question.dart';

class GameProgress extends Equatable {
  const GameProgress({
    this.questionIndex = 0,
    this.score = 0,
    this.revealedMask = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.finished = false,
  });

  final int questionIndex;
  final int score;
  final int revealedMask;
  final int correctCount;
  final int wrongCount;
  final bool finished;

  bool isRevealed(int index) => (revealedMask & (1 << index)) != 0;

  int valueFor(GameQuestion question) =>
      [
        for (var i = 0; i < question.letterCount; i++)
          if (!isRevealed(i)) i,
      ].length *
      100;

  GameProgress revealLetter(GameQuestion question, Random random) {
    if (finished) return this;
    final hidden = [
      for (var i = 0; i < question.letterCount; i++)
        if (!isRevealed(i)) i,
    ];
    // Keep one letter hidden: revealing the entire answer cannot bypass a penalty.
    if (hidden.length <= 1) return this;
    return GameProgress(
      questionIndex: questionIndex,
      score: score,
      revealedMask: revealedMask | (1 << hidden[random.nextInt(hidden.length)]),
      correctCount: correctCount,
      wrongCount: wrongCount,
    );
  }

  GameProgress resolve(
    List<GameQuestion> questions, {
    required bool correct,
    bool timedOut = false,
  }) {
    if (finished || questionIndex >= questions.length) return this;
    final value = valueFor(questions[questionIndex]);
    final nextIndex = questionIndex + 1;
    return GameProgress(
      questionIndex: nextIndex,
      score: score + (correct ? value : -value),
      correctCount: correctCount + (correct ? 1 : 0),
      wrongCount: wrongCount + (correct ? 0 : 1),
      finished: timedOut || nextIndex == questions.length,
    );
  }

  Map<String, Object?> toMap() => {
    'questionIndex': questionIndex,
    'score': score,
    'revealedMask': revealedMask,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    'finished': finished,
    'updatedAtMs': {'.sv': 'timestamp'},
  };

  static GameProgress fromMap(Object? value) {
    final map = value is Map ? value : const {};
    return GameProgress(
      questionIndex: (map['questionIndex'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt() ?? 0,
      revealedMask: (map['revealedMask'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (map['wrongCount'] as num?)?.toInt() ?? 0,
      finished: map['finished'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    questionIndex,
    score,
    revealedMask,
    correctCount,
    wrongCount,
    finished,
  ];
}
