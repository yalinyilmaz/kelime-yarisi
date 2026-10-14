import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_audio_cubit.dart';

class GameSoundButton extends StatelessWidget {
  const GameSoundButton({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<GameAudioCubit, bool>(
    builder: (context, enabled) => IconButton(
      tooltip: enabled ? 'Sesi kapat' : 'Sesi aç',
      onPressed: context.read<GameAudioCubit>().toggle,
      icon: Icon(enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
    ),
  );
}
