import 'package:flutter/services.dart';

import '../../domain/game_question.dart';

class WordLetterFormatter extends TextInputFormatter {
  WordLetterFormatter(this.question, this.hiddenPositions);

  final GameQuestion question;
  final List<int> hiddenPositions;

  String _formatLetters(String input) {
    final text = GameQuestion.normalizeAnswer(input)
        .replaceAll(RegExp('[^A-ZÇĞİÖŞÜ]'), '');
    return [
      for (var i = 0; i < text.length; i++)
        i < hiddenPositions.length
            ? question.normalizeLetter(text[i], hiddenPositions[i])
            : text[i],
    ].join();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final text = _formatLetters(newValue.text);
    final prefix = newValue.selection.extentOffset < 0
        ? newValue.text
        : newValue.text.substring(0, newValue.selection.extentOffset);
    final offset = _formatLetters(prefix).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
