import 'package:flutter/services.dart';

class RoomCodeFormatter extends TextInputFormatter {
  const RoomCodeFormatter();

  static const emptyValue = TextEditingValue(
    text: '   -   ',
    selection: TextSelection.collapsed(offset: 0),
  );

  static String normalize(String value) =>
      value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var code = normalize(newValue.text);
    int? cursor;

    // Pasting a complete code replaces a partial code, wherever the caret is.
    final selection = oldValue.selection;
    final insertedLength =
        newValue.text.length -
        oldValue.text.length +
        (selection.isValid ? selection.end - selection.start : 0);
    if (selection.isValid &&
        insertedLength > 0 &&
        selection.start + insertedLength <= newValue.text.length) {
      final inserted = normalize(
        newValue.text.substring(
          selection.start,
          selection.start + insertedLength,
        ),
      );
      if (inserted.length >= 6) {
        code = inserted;
        cursor = 6;
      }
    }

    // The separator is permanent: backspace across it deletes the preceding
    // character rather than trapping the caret at the hyphen.
    if (cursor == null &&
        selection.isCollapsed &&
        oldValue.text.length == 7 &&
        oldValue.text[3] == '-' &&
        newValue.text.length == 6 &&
        code == normalize(oldValue.text) &&
        (selection.extentOffset == 3 || selection.extentOffset == 4)) {
      final index = selection.extentOffset == 4 ? 2 : 3;
      if (index < code.length) {
        code = code.replaceRange(index, index + 1, '');
        cursor = index;
      }
    }

    if (code.length > 6) code = code.substring(0, 6);
    final padded = code.padRight(6);
    final text = '${padded.substring(0, 3)}-${padded.substring(3)}';
    int offset(int sourceOffset) {
      final count =
          cursor ??
          normalize(
            newValue.text.substring(
              0,
              sourceOffset.clamp(0, newValue.text.length),
            ),
          ).length.clamp(0, code.length);
      return count + (count >= 3 ? 1 : 0);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
    );
  }
}
