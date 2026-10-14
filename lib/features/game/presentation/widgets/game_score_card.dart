import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/game_answer_feedback.dart';
import '../cubit/game_feedback_cubit.dart';
import 'game_stat_card.dart';

class GameScoreCard extends StatelessWidget {
  const GameScoreCard({required this.score, super.key});
  final int score;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<GameFeedbackCubit, GameAnswerFeedback?>(
        builder: (context, result) => TweenAnimationBuilder<double>(
          key: ValueKey(score),
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 450),
          builder: (context, value, child) =>
              Transform.scale(scale: 1 + 0.06 * (1 - value), child: child),
          child: GameStatCard(
            label: 'PUANIN',
            value: '$score',
            color: result == null
                ? AppColors.cyan
                : result.isCorrect
                ? AppColors.ready
                : AppColors.danger,
          ),
        ),
      );
}
