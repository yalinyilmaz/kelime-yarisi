import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_actions.dart';

class GameAnswerActions extends StatelessWidget {
  const GameAnswerActions({
    required this.answerController,
    required this.onSubmit,
    super.key,
  });
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => BlocBuilder<GameCubit, GameState>(
    buildWhen: (a, b) =>
        a.canAct != b.canAct ||
        a.questionIndex != b.questionIndex ||
        a.question != b.question ||
        (a.errorMessage == null) != (b.errorMessage == null),
    builder: (context, state) => GameActions(
      state: state,
      answerController: answerController,
      onSubmit: onSubmit,
    ),
  );
}
