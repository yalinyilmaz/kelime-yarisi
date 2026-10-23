import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_yarisi/app/app_router.dart';
import 'package:kelime_yarisi/core/theme/app_theme.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_mapper.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/room/domain/entities/game_room.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_listing.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/multiplayer_home_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_home_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_directory_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_lobby_page.dart';
import 'package:kelime_yarisi/features/room/presentation/pages/room_setup_page.dart';
import 'package:kelime_yarisi/features/room/presentation/cubit/room_setup_cubit.dart';

import 'app_router_test.dart' show FakeLobbyService, withNamedPlayer;
import 'game_cubit_test.dart' show testRoom;

const publicRoom = RoomListing(
  id: 'public',
  name: 'Açık Yarış',
  visibility: RoomVisibility.public,
  playerCount: 1,
  capacity: 6,
);
const privateRoom = RoomListing(
  id: 'private',
  name: 'Özel Yarış',
  visibility: RoomVisibility.private,
  playerCount: 2,
  capacity: 6,
);

class _DirectoryService extends FakeLobbyService {
  List<RoomListing> entries = [publicRoom, privateRoom];
  Object? listError;
  Object? joinError;
  int loads = 0;
  final joins = <({String id, String name, String? code})>[];
  final leaves = <String>[];
  Completer<GameRoom>? joinGate;
  Completer<List<RoomListing>>? listGate;

  @override
  Future<List<RoomListing>> listRooms() async {
    loads++;
    if (listError != null) throw listError!;
    return listGate == null ? entries : listGate!.future;
  }

  @override
  Future<GameRoom> joinListedRoom({
    required String directoryId,
    required String displayName,
    String? roomCode,
  }) async {
    joins.add((id: directoryId, name: displayName, code: roomCode));
    if (joinError != null) throw joinError!;
    return joinGate == null
        ? testRoom().copyWith(status: RoomStatus.lobby)
        : joinGate!.future;
  }

  @override
  Future<GameRoom> createRoom({
    required String displayName,
    required String roomName,
    required int targetPlayerCount,
    required RoomGameMode gameMode,
    RoomVisibility visibility = RoomVisibility.private,
  }) async => room = GameRoom(
    id: 'abc234',
    name: roomName,
    code: 'ABC-234',
    hostId: uid,
    targetPlayerCount: targetPlayerCount,
    gameMode: gameMode,
    visibility: visibility,
    players: [testRoom().players.first],
  );

  @override
  Future<void> leaveRoom(String roomId) async => leaves.add(roomId);
}

void main() {
  Future<GoRouter> open(
    WidgetTester tester,
    _DirectoryService service, {
    String location = '/rooms',
    double scale = 1,
  }) async {
    final router = createAppRouter()..go(location);
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  test('visibility survives mapping/copy, while old rooms stay private', () {
    final old = FirebaseRoomMapper.fromMap('abc234', {});
    expect(old.visibility, RoomVisibility.private);
    final openRoom = FirebaseRoomMapper.fromMap('abc234', {
      'visibility': 'public',
    });
    expect(
      openRoom.copyWith(status: RoomStatus.playing).visibility,
      RoomVisibility.public,
    );
    expect(FirebaseRoomMapper.toMap(openRoom)['visibility'], 'public');
  });

  testWidgets(
    'mode cards keep quick mode inactive; continue opens list and plus opens creation with access choice',
    (tester) async {
      final service = _DirectoryService();
      final router = await open(tester, service, location: '/multiplayer');
      expect(find.text('Diğer oyuncularla yarış'), findsOneWidget);
      expect(find.text('Oda Oluştur'), findsNothing);
      await tester.ensureVisible(find.text('Hızlı Mod'));
      await tester.tap(find.text('Hızlı Mod'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/multiplayer');
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomDirectoryPage), findsOneWidget);
      await tester.tap(find.byTooltip('Oda oluştur'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomSetupPage), findsOneWidget);
      final setup = tester
          .element(find.byType(TextFormField))
          .read<RoomSetupCubit>();
      expect(setup.state.visibility, RoomVisibility.private);
      await tester.ensureVisible(find.text('Açık'));
      await tester.tap(find.text('Açık'));
      await tester.pumpAndSettle();
      expect(setup.state.visibility, RoomVisibility.public);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Açık Yarış'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Diğer oyuncularla yarış'), findsOneWidget);
    },
  );

  testWidgets(
    'create then leave returns through directory and multiplayer before home',
    (tester) async {
      final service = _DirectoryService()..uid = 'host';
      final router = await open(tester, service, location: '/multiplayer');
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Oda oluştur'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Odayı Kur'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(RoomSetupPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Odayı Kur'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomLobbyPage), findsOneWidget);
      await tester.tap(find.byTooltip('Odadan çık'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odadan Çık'));
      await tester.pumpAndSettle();
      expect(service.leaves, ['abc234']);
      expect(find.byType(RoomDirectoryPage), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/multiplayer/rooms',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MultiplayerHomePage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RoomHomePage), findsOneWidget);
    },
  );

  testWidgets(
    'public join goes straight to lobby, sends no code and blocks double taps',
    (tester) async {
      final service = _DirectoryService()..joinGate = Completer<GameRoom>();
      await open(tester, service);
      await tester.tap(find.text('Katıl').first);
      await tester.pump();
      await tester.tap(find.text('Katıl').first);
      await tester.pump();
      expect(service.joins, [(id: 'public', name: 'Yalın', code: null)]);
      expect(find.byKey(const ValueKey('room-code-input')), findsNothing);
      service.joinGate!.complete(testRoom().copyWith(status: RoomStatus.lobby));
      await tester.pumpAndSettle();
      expect(find.byType(RoomLobbyPage), findsOneWidget);
    },
  );

  testWidgets(
    'private join uses code popup with native paste, retains errors and allows retry',
    (tester) async {
      final service = _DirectoryService()
        ..joinError = const RoomServiceException(
          'permission-denied',
          'Oda kodu eşleşmedi.',
        );
      await open(tester, service);
      await tester.tap(find.text('Katıl').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(RoomSetupPage), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('room-code-input')),
        'abc-234',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odaya Gir'));
      await tester.pumpAndSettle();
      expect(find.text('Oda kodu eşleşmedi.'), findsOneWidget);
      expect(service.joins.single, (
        id: 'private',
        name: 'Yalın',
        code: 'ABC234',
      ));
      service.joinError = null;
      await tester.tap(find.text('Odaya Gir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(RoomLobbyPage), findsOneWidget);
    },
  );

  testWidgets('list failures retry, empty state and full room stay usable', (
    tester,
  ) async {
    final service = _DirectoryService()
      ..listError = const RoomServiceException(
        'unavailable',
        'Liste alınamadı.',
      );
    await open(tester, service);
    expect(find.text('Liste alınamadı.'), findsOneWidget);
    service.listError = null;
    service.entries = [];
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz açık oda yok'), findsOneWidget);
    service.entries = [
      const RoomListing(
        id: 'full',
        name: 'Dolu oda',
        visibility: RoomVisibility.public,
        playerCount: 2,
        capacity: 2,
      ),
    ];
    await tester.tap(find.byTooltip('Listeyi yenile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dolu'));
    expect(service.joins, isEmpty);
  });

  testWidgets(
    'late join after navigation releases membership instead of opening an orphan lobby',
    (tester) async {
      final service = _DirectoryService()..joinGate = Completer<GameRoom>();
      final router = await open(tester, service);
      await tester.tap(find.text('Katıl').first);
      await tester.pump();
      router.go('/');
      await tester.pumpAndSettle();
      service.joinGate!.complete(testRoom().copyWith(status: RoomStatus.lobby));
      await tester.pumpAndSettle();
      expect(service.leaves, ['abc234']);
      expect(find.byType(RoomLobbyPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small screen and large text keep mode cards, room tiles and private popup scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _DirectoryService();
      await open(tester, service, location: '/multiplayer', scale: 1.5);
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      final privateJoin = find.byKey(const ValueKey('join-room-private'));
      await tester.scrollUntilVisible(
        privateJoin,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(privateJoin);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('room-code-input')),
        'abc234',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Kapat'));
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomDirectoryPage), findsOneWidget);
      expect(service.joins, isEmpty);
    },
  );
}
