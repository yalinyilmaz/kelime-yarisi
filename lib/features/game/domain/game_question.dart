import 'package:equatable/equatable.dart';

class GameQuestion extends Equatable {
  const GameQuestion({required this.clue, required this.answer});

  final String clue;
  final String answer;

  int get letterCount => answer.length;

  bool accepts(String input) => _comparisonKey(input) == _comparisonKey(answer);

  // Resolve ambiguous ASCII letters using their position in this word.
  // Different letters stay different; only Turkish/ASCII equivalents are converted.
  String normalizeLetter(String input, int index) {
    final letter = normalizeAnswer(input);
    return _comparisonKey(letter) == _comparisonKey(answer[index])
        ? answer[index]
        : letter;
  }

  static String _comparisonKey(String input) =>
      normalizeAnswer(input)
          .replaceAll('Ç', 'C')
          .replaceAll('Ğ', 'G')
          .replaceAll('İ', 'I')
          .replaceAll('Ö', 'O')
          .replaceAll('Ş', 'S')
          .replaceAll('Ü', 'U')
          .replaceAll(RegExp(r'[\u0306-\u0308\u0327]'), '');

  static String normalizeAnswer(String input) => input
      .trim()
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '');

  @override
  List<Object?> get props => [clue, answer];
}
