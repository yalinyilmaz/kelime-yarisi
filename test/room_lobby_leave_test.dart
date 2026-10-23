import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/app/app_router.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_home_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_lobby_page.dart';

import 'app_router_test.dart' show FakeLobbyService, withNamedPlayer;
import 'game_cubit_test.dart' show testRoom;

void main() {
  for (final systemBack in [false, true]) {
    testWidgets(
      '${systemBack ? 'system back' : 'toolbar exit'} confirms first; only the dialog exit button spins until departure',
      (tester) async {
        final service = _LeaveService()..gate = Completer<void>();
        final room = testRoom().copyWith(status: RoomStatus.lobby);
        service.room = room;
        final router = createAppRouter()..go('/room/${room.id}', extra: room);
        addTearDown(() async {
          router.dispose();
          await service.disposeStreams();
        });
        await tester.pumpWidget(
          withNamedPlayer(
            RepositoryProvider<FirebaseRoomService>.value(
              value: service,
              child: MaterialApp.router(
                theme: AppTheme.dark,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> askToLeave() async {
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            final back = tester.widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Odadan çık',
              ),
            );
            back.onPressed!();
            back.onPressed!(); // Two taps must not stack two confirmation dialogs.
          }
          await tester.pumpAndSettle();
        }

        await askToLeave();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(service.leaves, 0);
        final stay = find.widgetWithText(OutlinedButton, 'Kal');
        final exit = find.widgetWithText(FilledButton, 'Odadan Çık');
        expect(stay, findsOneWidget);
        expect(exit, findsOneWidget);
        await tester.tap(stay);
        await tester.pumpAndSettle();
        expect(service.leaves, 0);
        expect(find.byType(RoomLobbyPage), findsOneWidget);
        await askToLeave();
        final confirm = tester.widget<FilledButton>(exit);
        confirm.onPressed!();
        confirm.onPressed!(); // One asynchronous leave request at a time.
        await tester.pump();
        await tester.pump();
        expect(service.leaves, 1);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(RoomLobbyPage), findsOneWidget);
        expect(
          find.descendant(
            of: exit,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        final ready = find.widgetWithText(FilledButton, 'Hazırım');
        expect(
          find.descendant(
            of: ready,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(tester.widget<FilledButton>(ready).onPressed, isNull);
        expect(tester.widget<FilledButton>(exit).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(stay).onPressed, isNull);
        await tester.binding.handlePopRoute();
        await tester.tapAt(const Offset(2, 2));
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(service.leaves, 1);
        service.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(RoomHomePage), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(service.rooms.hasListener, isFalse);
        expect(service.offsets.hasListener, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('failed leave keeps the confirmation open and allows retrying', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final service = _LeaveService()..gate = Completer<void>();
    final room = testRoom().copyWith(status: RoomStatus.lobby);
    service.room = room;
    final router = createAppRouter()..go('/room/${room.id}', extra: room);
    addTearDown(() async {
      router.dispose();
      await service.disposeStreams();
    });
    await tester.pumpWidget(
      withNamedPlayer(
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Odadan çık'));
    await tester.pumpAndSettle();
    final exit = find.widgetWithText(FilledButton, 'Odadan Çık');
    await tester.ensureVisible(exit);
    await tester.tap(exit);
    await tester.pump();
    service.gate!.completeError(StateError('leave failed'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Odadan çıkılamadı.'),
      ),
      findsOneWidget,
    );
    expect(find.byType(RoomLobbyPage), findsOneWidget);
    expect(tester.widget<FilledButton>(exit).onPressed, isNotNull);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Kal'))
          .onPressed,
      isNotNull,
    );
    expect(
      find.descendant(
        of: exit,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    service.gate = Completer<void>();
    await tester.ensureVisible(exit);
    await tester.tap(exit);
    await tester.pump();
    expect(service.leaves, 2);
    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RoomHomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _LeaveService extends FakeLobbyService {
  int leaves = 0;
  Completer<void>? gate;

  @override
  Future<void> leaveRoom(String roomId) async {
    leaves++;
    await gate?.future;
  }
}
