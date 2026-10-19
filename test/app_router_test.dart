import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/app/app_router.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/game/presentation/pages/game_page.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_home_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_lobby_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_setup_page.dart';
import 'package:kelime_yarisi/features/room/presentation/widgets/question_capacity_card.dart';

import 'game_cubit_test.dart' show FakeRoomService, testRoom;

class FakeLobbyService extends FakeRoomService {
  int starts = 0;
  final capacity = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> prepareQuestionHistory(String roomId) =>
      capacity.future;
  @override
  Future<void> beginPresence(String roomId) async {}
  @override
  Future<void> leaveRoom(String roomId) async {}
  @override
  Future<void> startCountdown(
    String roomId, {
    required int serverTimeOffsetMs,
    required RoomGameMode gameMode,
    required String questionEngine,
  }) async {
    starts++;
    publish(
      room.copyWith(
        status: RoomStatus.countdown,
        startsAtMs: DateTime.now().millisecondsSinceEpoch + 4000,
      ),
    );
  }
}

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'Pool loading indicator ends on ${fails ? 'failure' : 'success'}',
      (tester) async {
        final service = FakeLobbyService()..uid = 'host';
        final seed = testRoom();
        final room = GameRoom(
          id: seed.id,
          name: seed.name,
          code: seed.code,
          hostId: seed.hostId,
          targetPlayerCount: 2,
          gameMode: RoomGameMode.classic,
          players: seed.players,
          questionEngine: 'pool-v1',
        );
        service.room = room;
        final router = createAppRouter();
        router.go('/room/${room.id}', extra: room);
        await tester.pumpWidget(
          RepositoryProvider<FirebaseRoomService>.value(
            value: service,
            child: MaterialApp.router(
              theme: AppTheme.dark,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Soru havuzu yükleniyor…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(QuestionCapacityCard), findsNothing);
        if (fails) {
          service.capacity.completeError(
            const RoomServiceException(
              'unavailable',
              'Havuz bilgisi alınamadı.',
            ),
          );
        } else {
          service.capacity.complete({'groups': [], 'upperBoundSets': 48});
        }
        await tester.pumpAndSettle();
        expect(find.text('Soru havuzu yükleniyor…'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.byType(QuestionCapacityCard),
          fails ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await service.disposeStreams();
      },
    );
  }

  testWidgets(
    'Create/join routes return home; missing room data redirects safely',
    (tester) async {
      final service = FakeLobbyService();
      final router = createAppRouter();
      await tester.pumpWidget(
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oda Oluştur'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomSetupPage), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(RoomHomePage), findsOneWidget);
      await tester.tap(find.text('Odaya Katıl'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomSetupPage), findsOneWidget);
      router.go('/room/missing');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      router.go('/game/missing');
      await tester.pumpAndSettle();
      expect(find.byType(RoomHomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await service.disposeStreams();
    },
  );

  testWidgets(
    'Solo debug host starts countdown; playing replaces lobby; confirmed exit returns home',
    (tester) async {
      final service = FakeLobbyService()..uid = 'host';
      final seed = testRoom();
      final room = seed.copyWith(
        status: RoomStatus.lobby,
        players: [seed.players.first],
      );
      service.room = room;
      final router = createAppRouter();
      router.go('/room/${room.id}', extra: room);
      await tester.pumpWidget(
        RepositoryProvider<FirebaseRoomService>.value(
          value: service,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(room.everyoneIsReady, isFalse);
      expect(find.byType(RoomLobbyPage), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Oyunu Başlat · Debug'), 200);
      await tester.tap(find.text('Oyunu Başlat · Debug'));
      await tester.pump();
      expect(service.starts, 1);
      expect(service.room.status, RoomStatus.countdown);
      service.publish(
        service.room.copyWith(
          status: RoomStatus.playing,
          startsAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      service.offsets.add(0);
      service.connections.add(true);
      await tester.pump();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/game/${room.id}',
      );
      expect(find.byType(RoomLobbyPage), findsNothing);
      expect(find.byType(GamePage), findsOneWidget);
      await tester.tap(find.byTooltip('Odadan çık'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çık'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(RoomHomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await service.disposeStreams();
    },
  );
}
