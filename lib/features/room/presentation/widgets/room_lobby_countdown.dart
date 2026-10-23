import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/room_lobby_cubit.dart';
import '../cubit/room_lobby_state.dart';
import 'room_countdown_card.dart';

class RoomLobbyCountdown extends StatelessWidget {
  const RoomLobbyCountdown({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocSelector<RoomLobbyCubit, RoomLobbyState, int?>(
        selector: (s) => s.countdownSeconds,
        builder: (context, seconds) => seconds == null
            ? const SizedBox.shrink()
            : RoomCountdownCard(seconds: seconds),
      );
}
