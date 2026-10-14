import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../room/data/firebase_room_service.dart';
import '../../../room/domain/entities/game_room.dart';
import '../audio/game_sound_controller.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_audio_cubit.dart';
import '../cubit/game_feedback_cubit.dart';
import '../widgets/game_view.dart';

class GamePage extends StatelessWidget {
  const GamePage({required this.room, this.sounds, super.key});

  final GameRoom room;
  final GameSoundController? sounds;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => GameCubit(context.read<FirebaseRoomService>(), room),
      ),
      BlocProvider(
        create: (context) => GameFeedbackCubit(context.read<GameCubit>()),
      ),
      BlocProvider(
        create: (context) =>
            GameAudioCubit(context.read<GameCubit>(), sounds: sounds),
      ),
    ],
    child: const GameView(),
  );
}
