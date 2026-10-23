import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelime_yarisi/app/app.dart';
import 'package:kelime_yarisi/core/profile/player_name_cubit.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';
import 'package:kelime_yarisi/features/room/presentation/cubit/room_setup_cubit.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_home_page.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_best_score_cubit.dart';

import 'app_router_test.dart' show FakeLobbyService;
import 'game_cubit_test.dart' show testRoom;
import 'solo_game_test.dart' show MemoryScoreStorage;
import 'support/fake_native_speech.dart';

void main() {
  test('player name is normalized, validated and restored without overwriting the best score', () async {
    final storage = MemoryScoreStorage();
    final name = PlayerNameCubit(storage: storage);
    final best = SoloBestScoreCubit(storage: storage);
    expect(name.saveName('  Yalın   Yılmaz  '), isTrue);
    expect(name.state, 'Yalın Yılmaz');
    expect(name.saveName(' '), isFalse);
    expect(name.saveName('A'), isFalse);
    expect(name.saveName('a' * 25), isFalse);
    expect(name.state, 'Yalın Yılmaz');
    best.recordCompletedScore(7200);
    await name.close();
    await best.close();
    final restoredName = PlayerNameCubit(storage: storage);
    final restoredBest = SoloBestScoreCubit(storage: storage);
    expect(restoredName.state, 'Yalın Yılmaz');
    expect(restoredBest.state, 7200);
    await restoredName.close();
    await restoredBest.close();
  });

  test('invalid stored names return to the first step', () async {
    for (final value in [null, 7, '', 'a', 'a' * 25]) {
      final storage = MemoryScoreStorage();
      storage.values['player_name_v1'] = {'name': value};
      final name = PlayerNameCubit(storage: storage);
      expect(name.state, isNull);
      await name.close();
    }
  });

  test('name survives reopening the real hydrated storage', () async {
    final folder = await Directory.systemTemp.createTemp('ky_player_name_');
    try {
      final location = HydratedStorageDirectory(folder.path);
      final storage = await HydratedStorage.build(storageDirectory: location);
      final name = PlayerNameCubit(storage: storage)..saveName('Yalın');
      await name.close();
      await storage.close();
      final reopened = await HydratedStorage.build(storageDirectory: location);
      final restored = PlayerNameCubit(storage: reopened);
      expect(restored.state, 'Yalın');
      await restored.close();
      await reopened.close();
    } finally {
      await folder.delete(recursive: true);
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform: name gates modes, prefills an editable room name and is reused when joining',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final service = _SetupService();
        await tester.pumpWidget(
          KelimeYarisiApp(
            roomService: service,
            soloScoreStorage: MemoryScoreStorage(),
            speechRecognizer: FakeNativeSpeech(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tek Oyunculu'), findsNothing);
        final router = GoRouter.of(tester.element(find.byType(RoomHomePage)));
        router.go('/join');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        await tester.ensureVisible(find.text('Devam'));
        await tester.tap(find.text('Devam'));
        await tester.pump();
        expect(
          find.text('Oyuncu adın en az 2 karakter olmalı.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('player-name-input')),
          '  Yalın   Yılmaz  ',
        );
        await tester.ensureVisible(find.text('Devam'));
        await tester.tap(find.text('Devam'));
        await tester.pumpAndSettle();
        expect(find.text('Tek Oyunculu'), findsOneWidget);
        expect(find.text('Merhaba, Yalın Yılmaz'), findsOneWidget);
        await tester.tap(find.byTooltip('Oyuncu adını değiştir'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('player-name-input')),
          'Başka Ad',
        );
        await tester.ensureVisible(find.text('Vazgeç'));
        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();
        expect(find.text('Merhaba, Yalın Yılmaz'), findsOneWidget);
        await tester.tap(find.text('Çok Oyunculu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Oda Oluştur'));
        await tester.pumpAndSettle();
        expect(find.text('Oyuncu adın'), findsNothing);
        expect(find.text("Yalın Yılmaz's Room"), findsOneWidget);
        final setup = tester
            .element(find.byType(TextFormField))
            .read<RoomSetupCubit>();
        expect(setup.state.canSubmit, isTrue);
        await tester.enterText(find.byType(TextFormField), 'Akşam Yarışı');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Odayı Kur'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Odayı Kur'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Odayı Kur'));
        await tester.pumpAndSettle();
        expect(service.createdName, 'Yalın Yılmaz');
        expect(service.createdRoomName, 'Akşam Yarışı');
        router.go('/');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Çok Oyunculu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Odaya Katıl'));
        await tester.pumpAndSettle();
        expect(find.text('Oyuncu adın'), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('room-code-input')),
          'abc234',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Odaya Gir'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Odaya Gir'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Odaya Gir'));
        await tester.pumpAndSettle();
        expect(service.joinedName, 'Yalın Yılmaz');
        expect(service.joinedCode, 'ABC234');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.disposeStreams();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets(
    'stored names skip the form on every launch and remain editable on demand',
    (tester) async {
      final storage = MemoryScoreStorage();
      final saved = PlayerNameCubit(storage: storage)..saveName('Yalın');
      await saved.close();
      final service = _SetupService();
      await tester.pumpWidget(
        KelimeYarisiApp(
          roomService: service,
          soloScoreStorage: storage,
          speechRecognizer: FakeNativeSpeech(),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('player-name-input'));
      expect(input, findsNothing);
      expect(find.text('Merhaba, Yalın'), findsOneWidget);
      expect(find.text('Tek Oyunculu'), findsOneWidget);
      await tester.tap(find.byTooltip('Oyuncu adını değiştir'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(input).controller!.text, 'Yalın');
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: input, matching: find.byType(TextField)),
            )
            .readOnly,
        isFalse,
      );
      expect(find.text('Tek Oyunculu'), findsNothing);
      await tester.enterText(input, 'Ece');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Merhaba, Ece'), findsOneWidget);
      final persisted = Map<String, dynamic>.from(storage.values);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();

      final reopened = MemoryScoreStorage()..values.addAll(persisted);
      final nextService = _SetupService();
      await tester.pumpWidget(
        KelimeYarisiApp(
          roomService: nextService,
          soloScoreStorage: reopened,
          speechRecognizer: FakeNativeSpeech(),
        ),
      );
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(find.text('Merhaba, Ece'), findsOneWidget);
      expect(find.text('Tek Oyunculu'), findsOneWidget);
      await tester.tap(find.byTooltip('Oyuncu adını değiştir'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(input).controller!.text, 'Ece');
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('Tek Oyunculu'), findsOneWidget);
      expect(find.text('Merhaba, Ece'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await nextService.disposeStreams();
    },
  );

  testWidgets(
    'name entry scrolls above the keyboard on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = _SetupService();
      await tester.pumpWidget(
        KelimeYarisiApp(
          roomService: service,
          soloScoreStorage: MemoryScoreStorage(),
          speechRecognizer: FakeNativeSpeech(),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('player-name-input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Yalın');
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('Merhaba, Yalın'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.disposeStreams();
    },
  );
}

class _SetupService extends FakeLobbyService {
  String? createdName;
  String? createdRoomName;
  String? joinedName;
  String? joinedCode;

  @override
  Future<void> dispose() async {}

  @override
  Future<GameRoom> createRoom({
    required String displayName,
    required String roomName,
    required int targetPlayerCount,
    required RoomGameMode gameMode,
  }) async {
    createdName = displayName;
    createdRoomName = roomName;
    return room = testRoom().copyWith(status: RoomStatus.lobby);
  }

  @override
  Future<GameRoom> joinRoom({
    required String displayName,
    required String roomCode,
  }) async {
    joinedName = displayName;
    joinedCode = roomCode;
    return room = testRoom().copyWith(status: RoomStatus.lobby);
  }
}
