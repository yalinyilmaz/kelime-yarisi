import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/presentation/audio/game_sound_controller.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_state.dart';
import 'package:kelime_yarisi/features/game/presentation/cubit/game_cubit.dart';
import 'package:kelime_yarisi/features/game/presentation/pages/game_page.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_pin_input.dart';
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
  testWidgets(
    'iOS voting keeps the same editable connection; clock-only ticks do not rebuild the input',
    (tester) async {
      final service = FakeRoomService();
      final pending = Completer<void>();
      service.onHint = () => pending.future;
      final room = testRoom().copyWith(
        startsAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
      );
      service.room = room;
      await tester.pumpWidget(
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
            home: GamePage(room: room, sounds: FakeGameSounds()),
          ),
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      final focus = field.focusNode!;
      expect(focus.hasFocus, isTrue);
      final inputWidget = tester.widget<WordPinInput>(
        find.byType(WordPinInput),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<WordPinInput>(find.byType(WordPinInput)),
        same(inputWidget),
      );
      final cubit = tester.element(find.byType(WordPinInput)).read<GameCubit>();
      final request = cubit.revealLetter();
      await tester.pump();
      expect(cubit.state.isVoting, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(focus),
      );
      expect(focus.hasFocus, isTrue);
      pending.complete();
      await request;
      await tester.pump();
      expect(cubit.state.hints.revealedCount, 1);
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform: outside tap dismisses keyboard; fixed actions fit above keyboard and submit answers',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final service = FakeRoomService();
        final room = testRoom().copyWith(
          startsAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
        );
        await tester.pumpWidget(
          RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.dark.copyWith(platform: platform),
              home: GamePage(room: room, sounds: FakeGameSounds()),
            ),
          ),
        );
        service.offsets.add(0);
        service.connections.add(true);
        await tester.pump();
        await tester.pump();
        expect(find.text('SORU 1 / 7'), findsOneWidget);
        final focus = tester
            .widget<TextField>(find.byType(TextField))
            .focusNode!;
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.byTooltip('Sesi kapat'));
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.byTooltip('Sesi aç'), findsOneWidget);
        await tester.tap(find.byTooltip('Sesi aç'));
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isFalse,
        );
        await tester.enterText(find.byType(TextField), 'ka');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(service.saves, isEmpty);
        expect(find.text('Tüm boş harfleri doldur.'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        await tester.enterText(find.byType(TextField), 'kapi');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final answerAction = find.byKey(const ValueKey('answer-action'));
        final hintAction = find.byKey(const ValueKey('hint-action'));
        final answerRect = tester.getRect(answerAction);
        final hintRect = tester.getRect(hintAction);
        expect(answerRect.bottom, lessThanOrEqualTo(640 - 260));
        expect(answerRect.top, hintRect.top);
        expect(answerRect.right, lessThan(hintRect.left));
        await tester.drag(find.byType(ListView), const Offset(0, -120));
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        expect(tester.getRect(answerAction), answerRect);
        expect(tester.getRect(hintAction), hintRect);
        await tester.showKeyboard(find.byType(TextField));
        await tester.pump();
        final tap = await tester.startGesture(tester.getCenter(answerAction));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        expect(tester.getRect(answerAction), answerRect);
        await tap.up();
        await tester.pump();
        expect(service.saves.single.score, 400);
        expect(focus.hasFocus, isFalse);
        await tester.scrollUntilVisible(
          find.text('SORU 1 / 7'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('SORU 1 / 7'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'KAPI',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isTrue,
        );
        tester.view.resetViewInsets();
        await tester.pump();
        service.rooms.add(
          room.copyWith(
            progress: {
              'guest': service.saves.last,
              'host': const GameProgress(
                questionIndex: 1,
                wrongCount: 1,
                score: -400,
              ),
            },
          ),
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('CANLI PUANLAR'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('-400'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.disposeStreams();
      },
    );
  }

  testWidgets(
    'Equal results share a rank and final state removes answer controls',
    (tester) async {
      final service = FakeRoomService();
      final progress = const GameProgress(
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
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: GamePage(room: room, sounds: FakeGameSounds()),
          ),
        ),
      );
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Yarışma tamamlandı'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('SONUÇLAR'), 200);
      expect(find.text('1'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );
}
