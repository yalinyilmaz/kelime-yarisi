import 'game_question.dart';

class GameQuestionSet {
  const GameQuestionSet({required this.id, required this.questions});

  factory GameQuestionSet.fromMap(Map map) {
    final id = map['id'] as String;
    final questions = List<GameQuestion>.unmodifiable(
      (map['questions'] as List).map((q) => GameQuestion.fromMap(q as Map)),
    );
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(id) ||
        questions.length != 14 ||
        questions.indexed.any(
          (entry) =>
              entry.$2.letterCount != 4 + entry.$1 ~/ 2 ||
              entry.$2.id == null ||
              entry.$2.answerId == null ||
              entry.$2.clue.trim().isEmpty ||
              entry.$2.hints.length != 2 ||
              entry.$2.hints.any((hint) => hint.trim().isEmpty),
        ) ||
        questions.map((q) => q.id).toSet().length != 14 ||
        questions.map((q) => q.answerId).toSet().length != 14) {
      throw const FormatException('Soru seti geçersiz.');
    }
    return GameQuestionSet(id: id, questions: questions);
  }

  final String id;
  final List<GameQuestion> questions;
}
