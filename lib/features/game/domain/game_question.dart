import 'package:equatable/equatable.dart';

class GameQuestion extends Equatable {
  factory GameQuestion.fromMap(Map map) => GameQuestion(
    id: map['id'] as String?,
    answerId: map['answerId'] as String?,
    clue: map['clue'] as String? ?? '',
    answer: map['answer'] as String? ?? '',
    acceptedAnswers: List<String>.unmodifiable(
      (map['acceptedAnswers'] as List? ?? const []).cast<String>(),
    ),
    hints: List<String>.unmodifiable(
      (map['hints'] as List? ?? const []).cast<String>(),
    ),
  );
  const GameQuestion({
    required this.clue,
    required this.answer,
    this.id,
    this.answerId,
    this.acceptedAnswers = const [],
    this.hints = const [],
  });

  final String clue;
  final String answer;
  final String? id;
  final String? answerId;
  final List<String> acceptedAnswers;
  final List<String> hints;

  String get letters => normalizeAnswer(answer);

  int get letterCount => letters.length;

  List<int> get wordLengths => answer
      .trim()
      .split(RegExp(r'\s+'))
      .map((word) => normalizeAnswer(word).length)
      .toList(growable: false);

  bool accepts(String input) => [
    answer,
    ...acceptedAnswers,
  ].any((candidate) => _comparisonKey(input) == _comparisonKey(candidate));

  /// Voice answers may contain filler words or suffixes. Match the normalized
  /// answer anywhere in the final transcript, with all whitespace removed.
  String? answerInSpeech(String transcript) {
    final spoken = _comparisonKey(transcript);
    return [answer, ...acceptedAnswers].any((candidate) {
          final expected = _comparisonKey(candidate);
          return expected.isNotEmpty && spoken.contains(expected);
        })
        ? answer
        : null;
  }

  // Resolve ambiguous ASCII letters using their position in this word.
  // Different letters stay different; only Turkish/ASCII equivalents are converted.
  String normalizeLetter(String input, int index) {
    final letter = normalizeAnswer(input);
    return _comparisonKey(letter) == _comparisonKey(letters[index])
        ? letters[index]
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
  List<Object?> get props => [
    clue,
    answer,
    id,
    answerId,
    acceptedAnswers,
    hints,
  ];
}
