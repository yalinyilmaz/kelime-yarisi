import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/room_invitation.dart';
import '../core/profile/player_name_cubit.dart';

import '../features/game/presentation/pages/game_page.dart';
import '../features/room/domain/entities/game_room.dart';
import '../features/room/presentation/cubit/room_setup_state.dart';
import '../features/room/presentation/pages/room_home_page.dart';
import '../features/room/presentation/pages/room_invitation_page.dart';
import '../features/room/presentation/pages/room_lobby_page.dart';
import '../features/room/presentation/pages/room_setup_page.dart';
import '../features/room/presentation/pages/multiplayer_home_page.dart';
import '../features/solo/presentation/pages/solo_home_page.dart';
import '../features/solo/presentation/pages/solo_game_page.dart';

GoRouter createAppRouter({PlayerNameCubit? playerName}) => GoRouter(
  onEnter: (context, current, next, router) {
    if (next.uri.path.startsWith('/invite/') &&
        (current.uri.path.startsWith('/room/') ||
            current.uri.path.startsWith('/game/') ||
            current.uri.path == '/solo/play')) {
      return Block.then(
        () => showDialog<void>(
          context: router.routerDelegate.navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Oda daveti'),
            content: const Text(
              'Davete katılmak için önce mevcut oyundan veya odadan ayrıl.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
        ),
      );
    }
    return const Allow();
  },
  redirect: (_, state) {
    final uri = state.uri;
    if (uri.hasAuthority &&
        uri.host != Uri.parse(RoomInvitation.baseUrl).host) {
      return '/';
    }
    final isInvite = uri.path.startsWith('/invite/');
    final code = RoomInvitation.normalizeCode(
      isInvite ? uri.pathSegments.last : uri.queryParameters['code'],
    );
    if (isInvite) {
      if (code == null || uri.pathSegments.length != 2) return '/';
      if (playerName != null && playerName.state == null) {
        return Uri(path: '/', queryParameters: {'invite': code}).toString();
      }
      return null;
    }
    if (playerName != null && playerName.state == null && uri.path != '/') {
      return code != null && uri.path == '/join'
          ? Uri(path: '/', queryParameters: {'invite': code}).toString()
          : '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (_, state) => RoomHomePage(
        invitationCode: RoomInvitation.normalizeCode(
          state.uri.queryParameters['invite'],
        ),
      ),
      routes: [
        GoRoute(
          path: 'invite/:code',
          builder: (_, state) {
            final code = RoomInvitation.normalizeCode(
              state.pathParameters['code'],
            )!;
            return RoomInvitationPage(key: ValueKey(code), code: code);
          },
        ),
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
          builder: (_, state) => RoomSetupPage(
            key: ValueKey(state.uri.queryParameters['code']),
            flow: RoomSetupFlow.join,
            initialRoomCode:
                RoomInvitation.normalizeCode(
                  state.uri.queryParameters['code'],
                ) ??
                '',
          ),
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
