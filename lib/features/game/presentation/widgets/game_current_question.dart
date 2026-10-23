import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_question_card.dart';

class GameCurrentQuestion extends StatelessWidget {
  const GameCurrentQuestion({
    required this.answerController,
    required this.onSubmit,
    super.key,
  });
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => BlocBuilder<GameCubit, GameState>(
    buildWhen: (a, b) =>
        a.questionIndex != b.questionIndex ||
        a.question != b.question ||
        a.hints.revealedCount != b.hints.revealedCount ||
        a.canEditAnswer != b.canEditAnswer ||
        a.room.race?.isResolved != b.room.race?.isResolved,
    builder: (context, state) => GameQuestionCard(
      state: state,
      answerController: answerController,
      onSubmitted: onSubmit,
    ),
  );
}
