import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_clue_hints.dart';

class GameVisibleClueHints extends StatelessWidget {
  const GameVisibleClueHints({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<GameCubit, GameState>(
    buildWhen: (a, b) =>
        a.questionIndex != b.questionIndex ||
        a.currentClueHintCount != b.currentClueHintCount,
    builder: (context, state) => GameClueHints(hints: state.visibleClueHints),
  );
}
