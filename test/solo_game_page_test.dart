import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_yarisi/app/app.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_best_score_cubit.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_game_cubit.dart';
import 'package:kelime_yarisi/features/solo/presentation/pages/solo_game_page.dart';
import 'package:kelime_yarisi/features/solo/presentation/pages/solo_home_page.dart';
import 'package:kelime_yarisi/features/solo/presentation/widgets/solo_game_view.dart';

import 'solo_game_test.dart'
    show MemoryScoreStorage, SilentSoloSounds, SoloTestService;

void main() {
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
  GoRouter router,
) => tester.pumpWidget(
  RepositoryProvider<FirebaseRoomService>.value(
    value: service,
    child: BlocProvider<SoloBestScoreCubit>.value(
      value: best,
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    ),
  ),
);
