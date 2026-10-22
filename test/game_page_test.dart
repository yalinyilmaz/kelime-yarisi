import 'support/fake_native_speech.dart';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/presentation/audio/game_sound_controller.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_state.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/pages/game_page.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_pin_input.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_letter_cell.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/answer_feedback_banner.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;

class FakeGameSounds extends Fake implements GameSoundController {
  @override
  bool enabled = true;
  @override
  Future<void> initialize() async {}
  @override
  void update(GameState state) {}
  @override
  Future<void> setForeground(bool foreground) async {}
  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final correct in [true, false]) {
      testWidgets(
        '$platform: final voice answer scores once and reveals feedback; correct=$correct',
        (tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final service = FakeRoomService();
          final native = FakeNativeSpeech();
          final room = testRoom().copyWith(
            startsAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
          );
          service.room = room;
          await tester.pumpWidget(
            withSpeech(
              RepositoryProvider<FirebaseRoomService>.value(
                value: service,
                child: MaterialApp(
                  theme: AppTheme.dark.copyWith(platform: platform),
                  home: GamePage(room: room, sounds: FakeGameSounds()),
                ),
              ),
              recognizer: native,
            ),
          );
          service.offsets.add(0);
          service.connections.add(true);
          await tester.pump();
          expect(find.byType(TextField), findsNothing);
          expect(tester.testTextInput.isVisible, isFalse);
          final hold = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('answer-action'))),
          );
          await tester.pump();
          final question = tester
              .element(find.byType(WordPinInput))
              .read<GameCubit>()
              .state
              .question!;
          expect(native.lastOptions!.contextualPhrases, [
            question.answer,
            ...question.acceptedAnswers,
          ]);
          native.say('ka', finalResult: false);
          await tester.pump();
          expect(
            tester
                .widgetList<WordLetterCell>(find.byType(WordLetterCell))
                .every((c) => c.character == null),
            isTrue,
          );
          expect(service.saves, isEmpty);
          await hold.up();
          await tester.pump();
          native.say(correct ? 'bir düşüneyim cevabım kapıdır' : 'bilmiyorum');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 900));
          await tester.pumpAndSettle();
          expect(service.saves.single.score, correct ? 400 : -400);
          expect(
            find.text(correct ? 'Doğru cevap!' : 'Yanlış cevap'),
            findsOneWidget,
          );
          final cells = tester.widgetList<WordLetterCell>(
            find.byType(WordLetterCell),
          );
          expect(cells.map((c) => c.character).join(), 'KAPI');
          expect(
            cells.every(
              (c) =>
                  c.outcome ==
                  (correct ? AnswerOutcome.correct : AnswerOutcome.wrong),
            ),
            isTrue,
          );
          expect(find.byType(AnswerFeedbackBanner), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await service.disposeStreams();
        },
      );
    }
  }

  testWidgets(
    'letter voting keeps the PIN in place without opening a keyboard',
    (tester) async {
      final service = FakeRoomService();
      final room = testRoom().copyWith(
        startsAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
      );
      service.room = room;
      await tester.pumpWidget(
        withSpeech(
          RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: GamePage(room: room, sounds: FakeGameSounds()),
            ),
          ),
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      final cubit = tester.element(find.byType(WordPinInput)).read<GameCubit>();
      await tester.tap(find.byKey(const ValueKey('hint-action')));
      await tester.pump();
      expect(cubit.state.hints.revealedCount, 1);
      expect(
        tester
            .widgetList<WordLetterCell>(find.byType(WordLetterCell))
            .where((c) => c.revealed),
        hasLength(1),
      );
      expect(find.byType(TextField), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );

  testWidgets(
    'Equal results share a rank and final state removes answer controls',
    (tester) async {
      final service = FakeRoomService();
      const progress = GameProgress(
        questionIndex: 7,
        correctCount: 7,
        score: 4900,
        finished: true,
      );
      final room = testRoom(progress: {'host': progress, 'guest': progress})
          .copyWith(
            startsAtMs: DateTime.now().millisecondsSinceEpoch - 176000,
            status: RoomStatus.results,
          );
      await tester.pumpWidget(
        withSpeech(
          RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: GamePage(room: room, sounds: FakeGameSounds()),
            ),
          ),
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      expect(find.byKey(const ValueKey('answer-action')), findsNothing);
      expect(find.text('Yarışma tamamlandı'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('SONUÇLAR'), 200);
      expect(find.text('1'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );
}
