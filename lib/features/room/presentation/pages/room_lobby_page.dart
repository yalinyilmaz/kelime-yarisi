import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/firebase_room_service.dart';
import '../../domain/entities/game_room.dart';
import '../cubit/room_lobby_cubit.dart';
import '../widgets/room_lobby_view.dart';

class RoomLobbyPage extends StatelessWidget {
  const RoomLobbyPage({required this.room, super.key});

  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoomLobbyCubit(context.read<FirebaseRoomService>(), room),
      child: const RoomLobbyView(),
    );
  }
}
