import 'support/fake_native_speech.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_yarisi/app/app.dart';
import 'package:kelime_yarisi/core/profile/player_name_cubit.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_letter_cell.dart';
import 'package:kelime_yarisi/features/game/presentation/widgets/word_pin_input.dart';
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
    show MemoryScoreStorage, SilentSoloSounds, SoloTestService;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final compact in [false, true]) {
      testWidgets(
        '$platform: hints and letter cells stay in the card without a keyboard; compact=$compact',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = compact
              ? const Size(320, 640)
              : const Size(360, 800);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final service = SoloTestService();
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
          final game = tester
              .element(find.byType(SoloGameView))
              .read<SoloGameCubit>();
          for (var i = 0; i < 2; i++) {
            final hint = find.byKey(const ValueKey('clue-hint-action'));
            await tester.ensureVisible(hint);
            await tester.pumpAndSettle();
            await tester.tap(hint);
            await tester.pumpAndSettle();
          }
          expect(game.state.remainingHints, 8);
          final clueButton = find.byKey(const ValueKey('clue-hint-action'));
          expect(
            find.descendant(of: clueButton, matching: find.text('İpucu al  8')),
            findsOneWidget,
          );
          expect(find.text('8/10'), findsNothing);
          final pin = find.byType(WordPinInput);
          await tester.ensureVisible(pin);
          await tester.pumpAndSettle();
          expect(
            find.ancestor(of: pin, matching: find.byType(SoloQuestionCard)),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsNothing);
          expect(tester.testTextInput.isVisible, isFalse);
          await tester.tap(find.byKey(const ValueKey('hint-action')));
          await tester.pumpAndSettle();
          expect(game.state.revealedCount, 1);
          expect(
            tester
                .widgetList<WordLetterCell>(find.byType(WordLetterCell))
                .where((c) => c.revealed),
            hasLength(1),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          await best.close();
          await service.disposeStreams();
        },
      );
    }
  }

  testWidgets('hint count decreases to zero and hides only the hint button', (
    tester,
  ) async {
    final service = SoloTestService();
    final best = SoloBestScoreCubit(storage: MemoryScoreStorage());
    final router = _router();
    await _mount(tester, service, best, router);
    await tester.pumpAndSettle();
    final game = tester
        .element(find.byType(SoloGameView))
        .read<SoloGameCubit>();
    var remaining = 10;
    for (var question = 0; question < 5; question++) {
      for (var hint = 0; hint < 2; hint++) {
        final button = find.byKey(const ValueKey('clue-hint-action'));
        expect(
          find.descendant(
            of: button,
            matching: find.text('İpucu al  $remaining'),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(game.state.remainingHints, --remaining);
      }
      if (question < 4) {
        game.submitAnswer(game.state.question!.answer);
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle();
      }
    }
    expect(find.byKey(const ValueKey('clue-hint-action')), findsNothing);
    expect(find.textContaining('İpucu al'), findsNothing);
    expect(find.byType(WordPinInput), findsOneWidget);
    expect(game.state.visibleHints, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    await best.close();
    await service.disposeStreams();
  });

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
      final name = PlayerNameCubit(storage: storage)..saveName('Yalın');
      await name.close();
      final service = SoloTestService();
      await tester.pumpWidget(
        KelimeYarisiApp(
          roomService: service,
          soloScoreStorage: storage,
          speechRecognizer: FakeNativeSpeech(),
        ),
      );
      await tester.pumpAndSettle();
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
    'solo voice answer after revealing a letter earns the reduced value',
    (tester) async {
      final service = SoloTestService();
      final native = FakeNativeSpeech();
      final best = SoloBestScoreCubit(storage: MemoryScoreStorage());
      final router = _router();
      await _mount(tester, service, best, router, recognizer: native);
      await tester.pumpAndSettle();
      final game = tester
          .element(find.byType(SoloGameView))
          .read<SoloGameCubit>();
      await tester.tap(find.byKey(const ValueKey('hint-action')));
      await tester.pump();
      expect(game.state.revealedCount, 1);
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('answer-action'))),
      );
      await tester.pump();
      expect(native.lastOptions!.contextualPhrases, [
        game.state.question!.answer,
        ...game.state.question!.acceptedAnswers,
      ]);
      expect(find.byKey(const ValueKey('hint-action')), findsNothing);
      native.say('ka', finalResult: false);
      await tester.pump();
      expect(
        tester
            .widget<WordPinInput>(find.byType(WordPinInput))
            .answerController
            .text,
        isEmpty,
      );
      native.say('cevap kapıdır', finalResult: false);
      await tester.pump();
      expect(game.state.progress.score, 300);
      await hold.up();
      native.say('kapı');
      await tester.pump();
      expect(game.state.progress.score, 300);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(AnswerFeedbackBanner), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
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
  FakeNativeSpeech? recognizer,
  TextScaler textScaler = TextScaler.noScaling,
}) => tester.pumpWidget(
  withSpeech(
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
    recognizer: recognizer,
  ),
);
