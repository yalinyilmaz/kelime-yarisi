import 'package:go_router/go_router.dart';

import '../core/profile/player_name_cubit.dart';

import '../features/game/presentation/pages/game_page.dart';
import '../features/room/domain/entities/game_room.dart';
import '../features/room/presentation/cubit/room_setup_state.dart';
import '../features/room/presentation/pages/room_home_page.dart';
import '../features/room/presentation/pages/room_lobby_page.dart';
import '../features/room/presentation/pages/room_setup_page.dart';
import '../features/room/presentation/pages/multiplayer_home_page.dart';
import '../features/solo/presentation/pages/solo_home_page.dart';
import '../features/solo/presentation/pages/solo_game_page.dart';

GoRouter createAppRouter({PlayerNameCubit? playerName}) => GoRouter(
  redirect: (_, state) =>
      playerName != null &&
          playerName.state == null &&
          state.uri.path != '/'
      ? '/'
      : null,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const RoomHomePage(),
      routes: [
        GoRoute(
          path: 'multiplayer',
          builder: (_, _) => const MultiplayerHomePage(),
        ),
        GoRoute(
          path: 'solo',
          builder: (_, _) => const SoloHomePage(),
          routes: [
            GoRoute(path: 'play', builder: (_, _) => const SoloGamePage()),
          ],
        ),
        GoRoute(
          path: 'create',
          builder: (_, _) => const RoomSetupPage(flow: RoomSetupFlow.create),
        ),
        GoRoute(
          path: 'join',
          builder: (_, _) => const RoomSetupPage(flow: RoomSetupFlow.join),
        ),
        GoRoute(
          path: 'room/:id',
          redirect: (_, state) => _roomRedirect(state),
          builder: (_, state) => RoomLobbyPage(room: state.extra! as GameRoom),
        ),
        GoRoute(
          path: 'game/:id',
          redirect: (_, state) => _roomRedirect(state),
          builder: (_, state) => GamePage(room: state.extra! as GameRoom),
        ),
      ],
    ),
  ],
);

String? _roomRedirect(GoRouterState state) {
  final room = state.extra;
  return room is GameRoom && room.id == state.pathParameters['id'] ? null : '/';
}
