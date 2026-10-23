import '../widgets/room_invitation_view.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/player_name_cubit.dart';
import '../../data/firebase_room_service.dart';
import '../cubit/room_setup_cubit.dart';
import '../cubit/room_setup_state.dart';

class RoomInvitationPage extends StatelessWidget {
  const RoomInvitationPage({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RoomSetupCubit(
      context.read<FirebaseRoomService>(),
      flow: RoomSetupFlow.join,
      displayName: context.read<PlayerNameCubit>().state!,
      initialRoomCode: code,
    )..submit(),
    child: const RoomInvitationView(),
  );
}
