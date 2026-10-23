import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_clue_hint_button.dart';

class GameClueHintAction extends StatelessWidget {
  const GameClueHintAction({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocSelector<GameCubit, GameState, (int, int, bool, bool)>(
        selector: (s) => (
          s.remainingClueHints,
          s.currentClueHintCount,
          s.canRequestClueHint,
          s.question?.hints.length == 2,
        ),
        builder: (context, hint) => !hint.$4 || hint.$1 == 0
            ? const SizedBox.shrink()
            : GameClueHintButton(
                remaining: hint.$1,
                used: hint.$2,
                onPressed: hint.$3
                    ? context.read<GameCubit>().requestClueHint
                    : null,
              ),
      );
}
