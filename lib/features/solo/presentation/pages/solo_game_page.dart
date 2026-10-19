import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../game/presentation/audio/game_sound_controller.dart';
import '../../../room/data/firebase_room_service.dart';
import '../cubit/solo_best_score_cubit.dart';
import '../cubit/solo_game_cubit.dart';
import '../widgets/solo_game_view.dart';

class SoloGamePage extends StatelessWidget {
  const SoloGamePage({this.sounds, super.key});
  final GameSoundController? sounds;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SoloGameCubit(
      context.read<FirebaseRoomService>(),
      context.read<SoloBestScoreCubit>(),
      sounds: sounds,
    )..start(),
    child: const SoloGameView(),
  );
}
