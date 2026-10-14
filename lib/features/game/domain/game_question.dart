import 'package:equatable/equatable.dart';

class GameQuestion extends Equatable {
  const GameQuestion({required this.clue, required this.answer});

  final String clue;
  final String answer;

  int get letterCount => answer.length;

  bool accepts(String input) => normalizeAnswer(input) == answer;

  static String normalizeAnswer(String input) => input
      .trim()
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '');

  @override
  List<Object?> get props => [clue, answer];
}
