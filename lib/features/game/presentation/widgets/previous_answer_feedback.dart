import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/game_answer_feedback.dart';
import '../cubit/game_feedback_cubit.dart';
import 'answer_feedback_banner.dart';

class PreviousAnswerFeedback extends StatelessWidget {
  const PreviousAnswerFeedback({required this.questionIndex, super.key});

  final int questionIndex;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<GameFeedbackCubit, GameAnswerFeedback?>(
        builder: (context, result) =>
            result != null && result.questionIndex < questionIndex
            ? Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnswerFeedbackBanner(
                  result: result,
                  previousQuestion: true,
                ),
              )
            : const SizedBox.shrink(),
      );
}
