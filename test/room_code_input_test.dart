import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/presentation/widgets/room_code_formatter.dart';
import 'package:kelime_yarisi/features/room/presentation/widgets/room_code_input.dart';

TextEditingValue insert(TextEditingValue old, String text) {
  final start = old.selection.start;
  final end = old.selection.end;
  return const RoomCodeFormatter().formatEditUpdate(
    old,
    TextEditingValue(
      text: old.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    ),
  );
}

void main() {
  test('separator exists from the start, input uppercases and skips it automatically', () {
    var value = RoomCodeFormatter.emptyValue;
    expect(value.text, '   -   ');
    for (final character in 'abc234'.split('')) {
      value = insert(value, character);
      expect(value.text.length, 7);
      expect(value.text[3], '-');
      if (RoomCodeFormatter.normalize(value.text).length == 3) {
        expect(value.selection.extentOffset, 4);
      }
    }
    expect(value.text, 'ABC-234');
    expect(value.selection.extentOffset, 7);
    expect(insert(value, '5').text, 'ABC-234');
  });

  for (final pasted in ['xyz789', 'xyz-789', ' xyz - 789 ']) {
    test('pasting $pasted replaces a partial code at any caret position', () {
      final partial = insert(RoomCodeFormatter.emptyValue, 'ab');
      expect(insert(partial, pasted).text, 'XYZ-789');
      final full = insert(
        RoomCodeFormatter.emptyValue,
        'ABC234',
      ).copyWith(selection: const TextSelection.collapsed(offset: 2));
      expect(insert(full, pasted).text, 'XYZ-789');
    });
  }

  test('deleting across the permanent hyphen and replacing a selection keep editing usable', () {
    var value = insert(RoomCodeFormatter.emptyValue, 'abc234');
    value = value.copyWith(
      selection: const TextSelection(baseOffset: 1, extentOffset: 2),
    );
    value = insert(value, 'z');
    expect(value.text, 'AZC-234');
    value = value.copyWith(selection: const TextSelection.collapsed(offset: 7));
    for (var i = 0; i < 6; i++) {
      final caret = value.selection.extentOffset;
      value = const RoomCodeFormatter().formatEditUpdate(
        value,
        TextEditingValue(
          text: value.text.replaceRange(caret - 1, caret, ''),
          selection: TextSelection.collapsed(offset: caret - 1),
        ),
      );
    }
    expect(value, RoomCodeFormatter.emptyValue);
    expect(insert(value, 'a!@2#').text, 'A2 -   ');
  });

  for (final width in [320.0, 400.0, 800.0]) {
    testWidgets(
      'room code layout at $width keeps its icon, alignment and native paste',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final values = <String>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.getData') return {'text': 'abc-234'};
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: RoomCodeInput(onChanged: values.add, onSubmitted: () {}),
              ),
            ),
          ),
        );
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.key_rounded), findsOneWidget);
        final bounds = tester.getRect(find.byType(RoomCodeInput));
        expect(
          tester.getTopLeft(find.text('Oda kodu')).dx,
          lessThan(bounds.left + 80),
        );
        expect(
          tester
              .getTopLeft(
                find.text('Kodu yaz veya yapıştır; tire yazmana gerek yok.'),
              )
              .dx,
          closeTo(bounds.left + 20, 1),
        );
        final field = find.byKey(const ValueKey('room-code-input'));
        await tester.tap(find.byIcon(Icons.key_rounded));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.showKeyboard(field);
        await tester.pump();
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        double separatorCenter() {
          final render = editable.renderEditable;
          final box = render
              .getBoxesForSelection(
                const TextSelection(baseOffset: 3, extentOffset: 4),
              )
              .single;
          return render.localToGlobal(Offset((box.left + box.right) / 2, 0)).dx;
        }

        final center = separatorCenter();
        expect(center, closeTo(bounds.center.dx, 2));
        for (final text in ['a', 'ab', 'abc', 'abc234']) {
          await tester.enterText(field, text);
          await tester.pump();
          expect(separatorCenter(), closeTo(center, 0.1));
          expect(
            tester.state<EditableTextState>(find.byType(EditableText)),
            same(editable),
          );
        }
        await tester.enterText(field, 'ab');
        await editable.pasteText(SelectionChangedCause.toolbar);
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, 'ABC-234');
        expect(values.last, 'ABC234');
        expect(tester.testTextInput.isVisible, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
