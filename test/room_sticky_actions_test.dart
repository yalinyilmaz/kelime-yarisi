import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/app/app_router.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

import 'app_router_test.dart' show FakeLobbyService, withNamedPlayer;
import 'game_cubit_test.dart' show testRoom;

void main() {
  Future<void> open(
    WidgetTester tester,
    FakeLobbyService service,
    String path,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = createAppRouter()..go(path, extra: service.room);
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
  }

  testWidgets(
    'create button stays visible while settings scroll and above the keyboard',
    (tester) async {
      await open(tester, FakeLobbyService(), '/create');
      final button = find.widgetWithText(FilledButton, 'Odayı Kur');
      final initialRect = tester.getRect(button);
      expect(button.hitTestable(), findsOneWidget);
      expect(initialRect.bottom, lessThanOrEqualTo(544));
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.getRect(button), initialRect);
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextFormField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      tester.view.padding = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(568 - 240));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final host in [true, false]) {
    testWidgets(
      '${host ? 'host' : 'guest'} lobby actions and waiting text stay visible while six players scroll',
      (tester) async {
        final service = FakeLobbyService()..uid = host ? 'host' : 'guest';
        service.room = testRoom(
          mode: RoomGameMode.classic,
          playerCount: 6,
        ).copyWith(status: RoomStatus.lobby);
        await open(tester, service, '/room/${service.room.id}');
        final ready = find.widgetWithText(FilledButton, 'Hazırım');
        final start = find.widgetWithText(OutlinedButton, 'Oyunu Başlat');
        final waiting = find.text('Oyuncuların hazır olması bekleniyor.');
        final readyRect = tester.getRect(ready);
        final waitingRect = tester.getRect(waiting);
        final startRect = host ? tester.getRect(start) : null;
        expect(ready.hitTestable(), findsOneWidget);
        expect(waitingRect.bottom, lessThanOrEqualTo(544));
        if (host) {
          expect(start.hitTestable(), findsOneWidget);
          expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
        } else {
          expect(start, findsNothing);
        }
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0));
        expect(tester.getRect(ready), readyRect);
        expect(tester.getRect(waiting), waitingRect);
        if (host) expect(tester.getRect(start), startRect);
        service.publish(
          service.room.copyWith(
            players: service.room.players
                .map((player) => player.copyWith(isReady: true))
                .toList(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Oda sahibinin oyunu başlatması bekleniyor.').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Hazır Değilim').hitTestable(),
          findsOneWidget,
        );
        if (host) {
          expect(tester.widget<OutlinedButton>(start).onPressed, isNotNull);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
