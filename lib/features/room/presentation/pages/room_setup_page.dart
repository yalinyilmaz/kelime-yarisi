import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/player_name_cubit.dart';

import '../../data/firebase_room_service.dart';
import '../cubit/room_setup_cubit.dart';
import '../cubit/room_setup_state.dart';
import '../widgets/room_setup_view.dart';

class RoomSetupPage extends StatelessWidget {
  const RoomSetupPage({
    required this.flow,
    this.initialRoomCode = '',
    super.key,
  });

  final RoomSetupFlow flow;
  final String initialRoomCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoomSetupCubit(
        context.read<FirebaseRoomService>(),
        flow: flow,
        displayName: context.read<PlayerNameCubit>().state!,
        initialRoomCode: initialRoomCode,
      ),
      child: const RoomSetupView(),
    );
  }
}
