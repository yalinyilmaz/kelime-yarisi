import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/solo_game_cubit.dart';
import '../cubit/solo_game_state.dart';

class SoloGameActions extends StatelessWidget {
  const SoloGameActions({
    required this.state,
    required this.onSubmit,
    super.key,
  });
  final SoloGameState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('answer-action'),
            onPressed: state.canAct ? onSubmit : null,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Cevapla'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('hint-action'),
            onPressed: state.canRevealLetter
                ? context.read<SoloGameCubit>().revealLetter
                : null,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
            label: const Text('Harf Al'),
          ),
        ),
      ],
    ),
  );
}
