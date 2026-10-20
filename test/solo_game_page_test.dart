import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_yarisi/app/app.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:kelime_yarisi/features/game/domain/game_question_set.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_letter_cell.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_pin_input.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/game_clue_hints.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/answer_feedback_banner.dart';
import 'package:kelime_yarisi/features/solo/presentation/widgets/solo_question_card.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_best_score_cubit.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_game_cubit.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_game_state.dart';
import 'package:kelime_yarisi/features/solo/presentation/pages/solo_game_page.dart';
import 'package:kelime_yarisi/features/solo/presentation/pages/solo_home_page.dart';
import 'package:kelime_yarisi/features/solo/presentation/widgets/solo_game_view.dart';
import 'package:kelime_yarisi/features/solo/presentation/widgets/solo_result_card.dart';

import 'solo_game_test.dart'
    show MemoryScoreStorage, SilentSoloSounds, SoloTestService, testSoloSet;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final compact in [false, true]) {
      testWidgets(
        '$platform: question and hints scroll without moving the PIN out of its card; compact=$compact',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = compact
              ? const Size(320, 640)
              : const Size(360, 800);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);
          final original = testSoloSet();
          final service = SoloTestService()
            ..loadGate = (Completer<GameQuestionSet>()
              ..complete(
                GameQuestionSet(
                  id: original.id,
                  questions: [
                    for (final q in original.questions)
                      GameQuestion(
                        id: q.id,
                        answerId: q.answerId,
                        answer: q.answer,
                        clue: 'Bardağı dudağa götürüp sıvıyı ağızdan almak.',
                        hints: const [
                          'İlaç için de bu fiil kullanılır.',
                          'Suyun mideye ilerlemesini düşün, mastar biçiminde.',
                        ],
                      ),
                  ],
                ),
              ));
          final best = SoloBestScoreCubit(storage: MemoryScoreStorage());
          final router = _router();
          await _mount(
            tester,
            service,
            best,
            router,
            platform: platform,
            textScaler: TextScaler.linear(compact ? 1.6 : 1),
          );
          await tester.pumpAndSettle();
          final field = find.byType(TextField);
          await tester.enterText(field, 'ka');
          final connection = tester.state<EditableTextState>(
            find.byType(EditableText),
          );
          final focus = tester.widget<TextField>(field).focusNode!;
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          for (var i = 0; i < 2; i++) {
            final hint = find.byKey(const ValueKey('clue-hint-action'));
            await tester.ensureVisible(hint);
            await tester.pumpAndSettle();
            await tester.tap(hint);
            await tester.pumpAndSettle();
            expect(
              tester.state<EditableTextState>(find.byType(EditableText)),
              same(connection),
            );
            expect(focus.hasFocus, isTrue);
            expect(tester.testTextInput.isVisible, isTrue);
            expect(tester.widget<TextField>(field).controller!.text, 'KA');
          }
          final game = tester
              .element(find.byType(SoloGameView))
              .read<SoloGameCubit>();
          expect(game.state.currentHintCount, 2);
          final pinRect = tester.getRect(find.byType(WordPinInput));
          final viewport = tester.getRect(find.byType(ListView));
          final clueRect = tester.getRect(find.text(game.state.question!.clue));
          final hintRect = tester.getRect(find.byType(GameClueHints));
          final actions = tester.getRect(
            find.byKey(const ValueKey('answer-action')),
          );
          expect(
            find.ancestor(
              of: find.byType(WordPinInput),
              matching: find.byType(SoloQuestionCard),
            ),
            findsOneWidget,
          );
          if (!compact) {
            expect(clueRect.top, greaterThanOrEqualTo(viewport.top));
            expect(hintRect.top, greaterThanOrEqualTo(clueRect.bottom));
            expect(hintRect.bottom, lessThanOrEqualTo(pinRect.top));
          }
          expect(pinRect.bottom + 8, lessThanOrEqualTo(viewport.bottom));
          expect(pinRect.bottom, lessThan(actions.top));
          expect(actions.bottom, lessThanOrEqualTo(compact ? 340 : 500));
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .pixels,
            greaterThan(0),
          );
          for (final cell in find.byType(WordLetterCell).evaluate()) {
            final rect = tester.getRect(find.byWidget(cell.widget));
            expect(rect.top, greaterThanOrEqualTo(pinRect.top));
            expect(rect.bottom, lessThanOrEqualTo(pinRect.bottom));
          }
          if (compact) {
            // Oversized text cannot all fit at once. Reading it must not close the keyboard.
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            final previousOffset = position.pixels;
            await tester.drag(find.byType(ListView), const Offset(0, 160));
            await tester.pumpAndSettle();
            expect(position.pixels, lessThan(previousOffset));
            expect(focus.hasFocus, isTrue);
            expect(tester.testTextInput.isVisible, isTrue);
            expect(
              tester.getRect(find.byKey(const ValueKey('answer-action'))),
              actions,
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 320);
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byType(WordPinInput)).bottom,
              lessThanOrEqualTo(tester.getRect(find.byType(ListView)).bottom),
            );
          }
          await tester.tap(find.byKey(const ValueKey('hint-action')));
          await tester.pumpAndSettle();
          expect(game.state.revealedCount, 1);
          expect(focus.hasFocus, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          await best.close();
          await service.disposeStreams();
        },
      );
    }
  }

  testWidgets(
    'timeout result shows the saved best score and allows returning',
    (tester) async {
      final service = SoloTestService();
      final best = SoloBestScoreCubit(storage: MemoryScoreStorage());
      var now = 1000;
      var left = false;
      final game = SoloGameCubit(
        service,
        best,
        sounds: SilentSoloSounds(),
        nowMs: () => now,
      );
      await game.start();
      game.submitAnswer(game.state.question!.answer);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: game),
            BlocProvider.value(value: best),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: BlocBuilder<SoloGameCubit, SoloGameState>(
                builder: (_, state) =>
                    SoloResultCard(state: state, onLeave: () => left = true),
              ),
            ),
          ),
        ),
      );
      now += SoloGameState.duration.inMilliseconds;
      game.refreshTime();
      await tester.pumpAndSettle();
      expect(find.text('Süre doldu'), findsNWidgets(2));
      expect(find.text('400 / 9.800'), findsOneWidget);
      expect(find.text('Kişisel rekorun: 400'), findsOneWidget);
      expect(find.textContaining('yeniden karşına çıkabilir'), findsOneWidget);
      expect(service.completed, isEmpty);
      await tester.tap(find.text('Tek Oyunculuya Dön'));
      expect(left, isTrue);
      await tester.pumpWidget(const SizedBox());
      await game.close();
      await best.close();
      await service.disposeStreams();
    },
  );

  testWidgets('repeated Start taps open only one solo game and fetch one set', (
    tester,
  ) async {
    final service = SoloTestService();
    final best = SoloBestScoreCubit(storage: MemoryScoreStorage());
    final router = _router(initialLocation: '/solo');
    await _mount(tester, service, best, router);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('solo-start')),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/solo/play');
    expect(find.byType(SoloGamePage), findsOneWidget);
    expect(service.loads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    await best.close();
    await service.disposeStreams();
  });

  testWidgets(
    'home offers both modes; solo shows hydrated best score and only Start',
    (tester) async {
      final storage = MemoryScoreStorage();
      final service = SoloTestService();
      await tester.pumpWidget(
        KelimeYarisiApp(roomService: service, soloScoreStorage: storage),
      );
      expect(find.text('Tek Oyunculu'), findsOneWidget);
      expect(find.text('Çok Oyunculu'), findsOneWidget);
      await tester.tap(find.text('Tek Oyunculu'));
      await tester.pumpAndSettle();
      expect(find.text('— / 9.800'), findsOneWidget);
      expect(find.text('Başla'), findsOneWidget);
      expect(find.text('Devam Et'), findsNothing);
      tester
          .element(find.byType(SoloHomePage))
          .read<SoloBestScoreCubit>()
          .recordCompletedScore(7200);
      await tester.pumpAndSettle();
      expect(find.text('7200 / 9.800'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(storage.closed, isTrue);
      await service.disposeStreams();
    },
  );

  testWidgets(
    'solo letter and answer actions preserve keyboard above the action row on a narrow device',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final service = SoloTestService();
      final best = SoloBestScoreCubit(storage: MemoryScoreStorage());
      final router = _router();
      await _mount(tester, service, best, router);
      await tester.pumpAndSettle();
      final game = tester
          .element(find.byType(SoloGameView))
          .read<SoloGameCubit>();
      expect(find.text('4:20'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pump();
      final letter = find.byKey(const ValueKey('hint-action'));
      expect(tester.getBottomLeft(letter).dy, lessThanOrEqualTo(490));
      await tester.tap(letter);
      await tester.pump();
      expect(game.state.revealedCount, 1);
      expect(tester.testTextInput.isVisible, isTrue);
      final question = game.state.question!;
      final mask = game.state.revealedMask;
      final input = [
        for (var i = 0; i < question.letterCount; i++)
          if ((mask & (1 << i)) == 0) question.letters[i],
      ].join();
      await tester.enterText(find.byType(TextField), input);
      await tester.tap(find.byKey(const ValueKey('answer-action')));
      await tester.pump();
      expect(game.state.progress.score, 300);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 200));
      final viewport = tester.getRect(find.byType(ListView));
      final pin = tester.getRect(find.byType(WordPinInput));
      final feedback = tester.getRect(find.byType(AnswerFeedbackBanner));
      expect(pin.top, greaterThanOrEqualTo(viewport.top));
      expect(pin.bottom, lessThanOrEqualTo(feedback.top));
      expect(feedback.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(tester.testTextInput.isVisible, isTrue);
      expect(service.completed, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await best.close();
      await service.disposeStreams();
    },
  );

  testWidgets(
    'abandon dialog allows staying and confirmed departure discards partial score',
    (tester) async {
      final service = SoloTestService();
      final best = SoloBestScoreCubit(storage: MemoryScoreStorage());
      final router = _router();
      await _mount(tester, service, best, router);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Oyundan çık'));
      await tester.pumpAndSettle();
      expect(find.textContaining('puanın sayılmayacak'), findsOneWidget);
      await tester.tap(find.text('Oyuna Dön'));
      await tester.pumpAndSettle();
      expect(find.byType(SoloGamePage), findsOneWidget);
      await tester.tap(find.byTooltip('Oyundan çık'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oyunu Terk Et'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/solo');
      expect(service.completed, isEmpty);
      expect(best.state, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await best.close();
      await service.disposeStreams();
    },
  );
}

GoRouter _router({String initialLocation = '/solo/play'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/solo', builder: (_, _) => const SoloHomePage()),
    GoRoute(
      path: '/solo/play',
      builder: (_, _) => SoloGamePage(sounds: SilentSoloSounds()),
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  SoloTestService service,
  SoloBestScoreCubit best,
  GoRouter router, {
  TargetPlatform? platform,
  TextScaler textScaler = TextScaler.noScaling,
}) => tester.pumpWidget(
  RepositoryProvider<FirebaseRoomService>.value(
    value: service,
    child: BlocProvider<SoloBestScoreCubit>.value(
      value: best,
      child: MaterialApp.router(
        theme: AppTheme.dark.copyWith(platform: platform),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  ),
);
