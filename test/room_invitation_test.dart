import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/app/app_router.dart';
import 'package:kelime_yarisi/core/config/room_invitation.dart';
import 'package:kelime_yarisi/core/profile/player_name_cubit.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_home_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_invitation_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_lobby_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_setup_page.dart';

import 'app_router_test.dart' show FakeLobbyService;
import 'game_cubit_test.dart' show testRoom;
import 'solo_game_test.dart' show MemoryScoreStorage;
import 'support/fake_native_speech.dart';

void main() {
  test('invites normalize full codes, reject malformed values and leave prod blank', () {
    expect(
      RoomInvitation.link('abc234').toString(),
      '${RoomInvitation.devBaseUrl}/invite/ABC-234',
    );
    expect(RoomInvitation.normalizeCode('abc-234'), 'ABC-234');
    for (final code in [
      null,
      '',
      'ABC',
      'ABC--234',
      'ABC/234',
      'ABC2347',
      '<svg>',
    ]) {
      expect(RoomInvitation.normalizeCode(code), isNull);
    }
    expect(RoomInvitation.prodBaseUrl, isEmpty);
    expect(
      RoomInvitation.link('ABC-234', base: RoomInvitation.prodBaseUrl),
      isNull,
    );
  });

  for (final hasName in [false, true]) {
    testWidgets(
      'invitation joins automatically ${hasName ? 'with a saved name' : 'after name entry'} without the code form',
      (tester) async {
        final player = PlayerNameCubit(storage: MemoryScoreStorage());
        if (hasName) player.saveName('Yalın');
        final service = _InvitationService()..joinGate = Completer<GameRoom>();
        final router = createAppRouter(playerName: player);
        router.go('${RoomInvitation.devBaseUrl}/invite/abc-234');
        addTearDown(() async {
          router.dispose();
          await player.close();
          await service.disposeStreams();
        });
        await tester.pumpWidget(
          BlocProvider.value(
            value: player,
            child: RepositoryProvider<FirebaseRoomService>.value(
              value: service,
              child: withSpeech(
                MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
              ),
            ),
          ),
        );
        await tester.pump();
        if (!hasName) {
          await tester.pumpAndSettle();
          expect(service.joinedCodes, isEmpty);
          expect(
            router.routeInformationProvider.value.uri.queryParameters['invite'],
            'ABC-234',
          );
          await tester.enterText(
            find.byKey(const ValueKey('player-name-input')),
            'Deniz',
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('save-player-name')),
          );
          await tester.tap(find.byKey(const ValueKey('save-player-name')));
          await tester.pump();
        }
        await tester.pump();
        expect(find.byType(RoomSetupPage), findsNothing);
        expect(find.byKey(const ValueKey('room-code-input')), findsNothing);
        expect(find.text('Odaya katılıyorsun'), findsOneWidget);
        expect(service.joinedCodes, ['ABC-234']);
        expect(service.joinedNames, [hasName ? 'Yalın' : 'Deniz']);
        router.go(RoomInvitation.joinLocation('ABC-234'));
        await tester.pump();
        await tester.pump();
        expect(service.joinedCodes, hasLength(1));
        service.joinGate!.complete(service.room);
        await tester.pumpAndSettle();
        expect(find.byType(RoomLobbyPage), findsOneWidget);
        expect(find.byType(RoomInvitationPage), findsNothing);
        expect(service.leftRooms, isEmpty);
        router.go('/');
        await tester.pumpAndSettle();
        router.go('${RoomInvitation.devBaseUrl}/invite/invalid');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(service.joinedCodes, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final error in [
    const RoomServiceException(
      'join-rejected',
      'Oda bulunamadı, dolu veya oyun başlamış olabilir.',
    ),
    const RoomServiceException('room-closed', 'Oda kapatıldı.'),
    const RoomServiceException('room-not-found', 'Oda bulunamadı.'),
    const RoomServiceException(
      'app-check-failed',
      'Uygulama doğrulanamadı. Tekrar deneyin.',
    ),
  ]) {
    testWidgets(
      '${error.code}: explanation allows retrying the same code once and returning home',
      (tester) async {
        if (error.code == 'join-rejected') {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final player = PlayerNameCubit(storage: MemoryScoreStorage())
          ..saveName('Yalın');
        final service = _InvitationService()..failure = error;
        final router = createAppRouter(playerName: player)
          ..go(RoomInvitation.joinLocation('ABC-234'));
        addTearDown(() async {
          router.dispose();
          await player.close();
          await service.disposeStreams();
        });
        await tester.pumpWidget(
          BlocProvider.value(
            value: player,
            child: RepositoryProvider<FirebaseRoomService>.value(
              value: service,
              child: withSpeech(
                MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = switch (error.code) {
          'room-closed' || 'room-not-found' => 'Oda artık aktif değil',
          'join-rejected' => 'Oda müsait değil',
          _ => 'Odaya katılamadın',
        };
        expect(find.text(title), findsOneWidget);
        expect(find.text('Tekrar Dene'), findsOneWidget);
        expect(find.text('Ana Menüye Dön'), findsOneWidget);
        expect(find.byType(RoomSetupPage), findsNothing);
        service.joinGate = Completer<GameRoom>();
        final retry = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Tekrar Dene'),
        );
        retry.onPressed!();
        retry.onPressed!();
        await tester.pump();
        await tester.pump();
        expect(service.joinedCodes, ['ABC-234', 'ABC-234']);
        expect(find.text('Tekrar Dene'), findsNothing);
        service.joinGate!.completeError(error);
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        await tester.ensureVisible(find.text('Ana Menüye Dön'));
        await tester.tap(find.text('Ana Menüye Dön'));
        await tester.pumpAndSettle();
        expect(find.text('Merhaba, Yalın'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('retry can enter after a room becomes available', (tester) async {
    final player = PlayerNameCubit(storage: MemoryScoreStorage())
      ..saveName('Yalın');
    final service = _InvitationService()
      ..failure = const RoomServiceException(
        'join-rejected',
        'Oda müsait değil.',
      );
    final router = createAppRouter(playerName: player)
      ..go(RoomInvitation.joinLocation('ABC-234'));
    addTearDown(() async {
      router.dispose();
      await player.close();
      await service.disposeStreams();
    });
    await tester.pumpWidget(
      BlocProvider.value(
        value: player,
        child: RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: withSpeech(
            MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    service.failure = null;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.byType(RoomLobbyPage), findsOneWidget);
    expect(service.joinedCodes, ['ABC-234', 'ABC-234']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving during automatic join cleans up the late membership', (
    tester,
  ) async {
    final player = PlayerNameCubit(storage: MemoryScoreStorage())
      ..saveName('Yalın');
    final service = _InvitationService()..joinGate = Completer<GameRoom>();
    final router = createAppRouter(playerName: player)
      ..go(RoomInvitation.joinLocation('ABC-234'));
    addTearDown(() async {
      router.dispose();
      await player.close();
      await service.disposeStreams();
    });
    await tester.pumpWidget(
      BlocProvider.value(
        value: player,
        child: RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: withSpeech(
            MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.joinedCodes, ['ABC-234']);
    await tester.tap(find.text('Ana Menüye Dön'));
    await tester.pumpAndSettle();
    service.joinGate!.complete(service.room);
    await tester.pumpAndSettle();
    expect(find.byType(RoomHomePage), findsOneWidget);
    expect(find.byType(RoomLobbyPage), findsNothing);
    expect(service.leftRooms, [service.room.id]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'an invitation preserves active room membership and shows a dismissible explanation',
    (tester) async {
      final player = PlayerNameCubit(storage: MemoryScoreStorage())
        ..saveName('Yalın');
      final service = FakeLobbyService()..uid = 'host';
      final room = testRoom();
      service.room = room;
      final router = createAppRouter(playerName: player)
        ..go('/room/${room.id}', extra: room);
      addTearDown(() async {
        router.dispose();
        await player.close();
        await service.disposeStreams();
      });
      await tester.pumpWidget(
        BlocProvider.value(
          value: player,
          child: RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: withSpeech(
              MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('${RoomInvitation.devBaseUrl}/invite/XYZ-789');
      await tester.pumpAndSettle();
      expect(find.text('Oda daveti'), findsOneWidget);
      expect(find.byType(RoomLobbyPage), findsOneWidget);
      expect(find.byType(RoomSetupPage), findsNothing);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _InvitationService extends FakeLobbyService {
  _InvitationService() {
    room = testRoom().copyWith(status: RoomStatus.lobby);
  }

  final joinedCodes = <String>[];
  final joinedNames = <String>[];
  final leftRooms = <String>[];
  Completer<GameRoom>? joinGate;
  RoomServiceException? failure;

  @override
  Future<GameRoom> joinRoom({
    required String displayName,
    required String roomCode,
  }) async {
    joinedCodes.add(roomCode);
    joinedNames.add(displayName);
    if (joinGate case final gate?) return gate.future;
    if (failure case final error?) throw error;
    return room;
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    leftRooms.add(roomId);
  }
}
