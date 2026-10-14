import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_pin_input.dart';

void main() {
  testWidgets(
    'iOS autofocus waits for the route transition and does not reopen a dismissed keyboard on hints',
    (tester) async {
      final answer = TextEditingController();
      var mask = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: StatefulBuilder(
                        builder: (context, setState) {
                          rebuild = setState;
                          return WordPinInput(
                            question: const GameQuestion(
                              clue: '',
                              answer: 'KAPI',
                            ),
                            questionIndex: 0,
                            revealedMask: mask,
                            enabled: true,
                            answerController: answer,
                            onSubmitted: () {},
                          );
                        },
                      ),
                    ),
                  ),
                ),
                child: const Text('Başla'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Başla'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isFalse);
      final route = ModalRoute.of(tester.element(find.byType(WordPinInput)))!;
      await tester.pump(route.transitionDuration);
      await tester.pump();
      expect(
        ModalRoute.of(tester.element(find.byType(WordPinInput)))!
            .animation!
            .status,
        AnimationStatus.completed,
      );
      field = tester.widget<TextField>(find.byType(TextField));
      final focus = field.focusNode!;
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      focus.unfocus();
      await tester.pump();
      rebuild(() => mask = 2);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(focus),
      );
      expect(focus.hasFocus, isFalse);
      await tester.pumpWidget(const SizedBox());
      answer.dispose();
    },
  );

  testWidgets(
    'ASCII typing converts to Turkish in the correct positions around shared hints',
    (tester) async {
      const question = GameQuestion(clue: '', answer: 'GÖKKUŞAĞI');
      final answer = TextEditingController();
      var mask = (1 << 1) | (1 << 5); // Ö and Ş are already shared hints.
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return WordPinInput(
                  question: question,
                  questionIndex: 0,
                  revealedMask: mask,
                  enabled: true,
                  answerController: answer,
                  onSubmitted: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'gkkuagi');
      expect(answer.text, 'GÖKKUŞAĞI');
      expect(question.accepts(answer.text), isTrue);
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(controller.text, 'GKKUAĞI');
      rebuild(() => mask |= 1 << 7); // Shared Ğ removes only its typed slot.
      await tester.pump();
      expect(controller.text, 'GKKUAI');
      expect(answer.text, 'GÖKKUŞAĞI');
      await tester.enterText(find.byType(TextField), 'gekuai');
      expect(answer.text, 'GÖEKUŞAĞI');
      expect(question.accepts(answer.text), isFalse);
      await tester.pumpWidget(const SizedBox());
      answer.dispose();
    },
  );

  testWidgets(
    'Hints keep typed positions, stay locked, and submission composes the full word',
    (tester) async {
      final answer = TextEditingController();
      var mask = 0;
      var questionIndex = 0;
      var enabled = true;
      var submits = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return WordPinInput(
                  question: const GameQuestion(clue: '', answer: 'KAPI'),
                  questionIndex: questionIndex,
                  revealedMask: mask,
                  enabled: enabled,
                  answerController: answer,
                  onSubmitted: () => submits++,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'kapı');
      expect(answer.text, 'KAPI');
      rebuild(() => mask = 2); // Open A, dropping only its typed position.
      await tester.pump();
      expect(controller.text, 'KPI');
      expect(answer.text, 'KAPI');
      expect(answer.text, 'KAPI');
      await tester.enterText(find.byType(TextField), 'k');
      expect(answer.text, 'KA');
      expect(find.text('A'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'kpı');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submits, 1);
      expect(answer.text, 'KAPI');
      rebuild(() {
        mask = 0;
        enabled = false;
      });
      await tester.pump();
      rebuild(() {
        questionIndex++;
        enabled = true;
      });
      await tester.pump();
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(answer.text, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      answer.dispose();
    },
  );

  testWidgets(
    'Ten letter input fits narrow screens with keyboard and sanitizes paste',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final answer = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: WordPinInput(
                question: const GameQuestion(clue: '', answer: 'BİLGİSAYAR'),
                questionIndex: 6,
                revealedMask: 0,
                enabled: true,
                answerController: answer,
                onSubmitted: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'bilgi sayar!123');
      expect(answer.text, 'BİLGİSAYAR');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox());
      answer.dispose();
    },
  );
}
