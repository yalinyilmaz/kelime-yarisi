import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';

class GameActions extends StatelessWidget {
  const GameActions({super.key, required this.state, required this.onSubmit});

  final GameState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('answer-action'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: state.canAct ? onSubmit : null,
            icon: state.isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: const Text('Cevapla'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('hint-action'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: state.canVote
                ? context.read<GameCubit>().revealLetter
                : null,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Harf Al'),
                Text(
                  state.isVoting
                      ? 'Kaydediliyor…'
                      : state.hasVoted
                      ? 'Oy verdin · 1/${state.room.requiredHintVotes}'
                      : '${state.hints.firstVoterId == null ? 0 : 1}/${state.room.requiredHintVotes} oy',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
