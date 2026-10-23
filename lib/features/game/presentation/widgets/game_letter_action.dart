import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';

class GameLetterAction extends StatelessWidget {
  const GameLetterAction({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<GameCubit, GameState, (bool, bool, bool, int, String?)>(
    selector: (s) => (
      s.canVote,
      s.isVoting,
      s.hasVoted,
      s.room.requiredHintVotes,
      s.hints.firstVoterId,
    ),
    builder: (context, _) {
      final state = context.read<GameCubit>().state;
      return OutlinedButton.icon(
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
      );
    },
  );
}
