import 'package:equatable/equatable.dart';

import 'game_progress.dart';
import 'game_question.dart';

class GameAnswerFeedback extends Equatable {
  const GameAnswerFeedback({
    required this.questionIndex,
    required this.question,
    required this.outcome,
    required this.scoreDelta,
  });

  final int questionIndex;
  final GameQuestion question;
  final AnswerOutcome outcome;
  final int scoreDelta;

  bool get isCorrect => outcome == AnswerOutcome.correct;
  String get label => switch (outcome) {
    AnswerOutcome.correct => 'Doğru cevap!',
    AnswerOutcome.wrong => 'Yanlış cevap',
    AnswerOutcome.timeout => 'Süre doldu',
  };

  @override
  List<Object?> get props => [questionIndex, question, outcome, scoreDelta];
}
