import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/app/app_router.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/presentation/cubit/room_lobby_cubit.dart';

import 'app_router_test.dart' show FakeLobbyService, withNamedPlayer;
import 'game_cubit_test.dart' show testRoom;

GameRoom partialRoom(int count) {
  final base = testRoom(playerCount: 6);
  return base.copyWith(
    status: RoomStatus.lobby,
    players: base.players
        .take(count)
        .map((p) => p.copyWith(isReady: true))
        .toList(),
  );
}

void main() {
  test('capacity is a maximum; release requires two ready online players and only the host can start', () {
    for (final count in [2, 3, 6]) {
      final room = partialRoom(count);
      expect(room.canStart(playerId: 'host'), isTrue);
      expect(room.canStart(playerId: 'guest'), isFalse);
      expect(room.everyoneIsReady, isTrue);
      expect(room.isFull, count == 6);
      expect(room.requiredHintVotes, count <= 3 ? 1 : 2);
    }
    final single = partialRoom(1);
    expect(single.canStart(playerId: 'host'), isFalse);
    expect(single.canStart(playerId: 'host', allowSolo: true), isTrue);
    final room = partialRoom(2);
    expect(
      room
          .copyWith(
            players: [
              room.players.first,
              room.players.last.copyWith(isReady: false),
            ],
          )
          .canStart(playerId: 'host'),
      isFalse,
    );
    expect(
      room
          .copyWith(
            players: [
              room.players.first,
              room.players.last.copyWith(isOnline: false),
            ],
          )
          .canStart(playerId: 'host'),
      isFalse,
    );
    expect(
      room.copyWith(status: RoomStatus.countdown).canStart(playerId: 'host'),
      isFalse,
    );
  });

  for (final scenario in [
    'host with two players',
    'guest with two players',
    'debug host alone',
  ]) {
    testWidgets(
      '$scenario: readiness never starts automatically; only the host gets Start',
      (tester) async {
        final isHost = !scenario.startsWith('guest');
        final count = scenario.endsWith('alone') ? 1 : 2;
        final service = FakeLobbyService()..uid = isHost ? 'host' : 'guest';
        final ready = partialRoom(count);
        service.room = ready.copyWith(
          players: ready.players
              .map((p) => p.copyWith(isReady: false))
              .toList(),
        );
        final router = createAppRouter()
          ..go('/room/${ready.id}', extra: service.room);
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
        final start = find.widgetWithText(OutlinedButton, 'Oyunu Başlat');
        if (isHost) {
          await tester.scrollUntilVisible(start, 200);
          expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
        }
        service.publish(ready);
        await tester.pumpAndSettle();
        expect(service.starts, 0);
        await tester.scrollUntilVisible(
          find.text('Oda sahibinin oyunu başlatması bekleniyor.'),
          200,
        );
        expect(
          find.text('Oda sahibinin oyunu başlatması bekleniyor.'),
          findsOneWidget,
        );
        if (isHost) {
          expect(tester.widget<OutlinedButton>(start).onPressed, isNotNull);
          await tester.ensureVisible(start);
          await tester.tap(start);
          await tester.pumpAndSettle();
          expect(service.starts, 1);
          expect(service.room.status, RoomStatus.countdown);
        } else {
          expect(start, findsNothing);
          final cubit = tester
              .element(find.text('Oda sahibinin oyunu başlatması bekleniyor.'))
              .read<RoomLobbyCubit>();
          await cubit.startGame();
          expect(service.starts, 0);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
