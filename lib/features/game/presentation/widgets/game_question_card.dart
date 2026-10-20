import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../domain/game_answer_feedback.dart';
import '../cubit/game_feedback_cubit.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'answer_feedback_banner.dart';
import 'word_pin_input.dart';
import 'game_clue_hints.dart';
import 'game_question_content.dart';

class GameQuestionCard extends StatelessWidget {
  const GameQuestionCard({
    required this.state,
    required this.answerController,
    required this.onSubmitted,
    super.key,
  });

  final GameState state;
  final TextEditingController answerController;
  final VoidCallback onSubmitted;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<GameFeedbackCubit, GameAnswerFeedback?>(
    builder: (context, result) {
      final currentResult = result?.questionIndex == state.questionIndex
          ? result
          : null;
      final question = state.question!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GameQuestionContent(
                questionIndex: state.questionIndex,
                header: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: StudioSectionLabel(
                          'SORU ${state.questionIndex + 1} / ${state.questions.length}',
                        ),
                      ),
                      if (question.hints.length == 2)
                        GameClueHintButton(
                          remaining: state.remainingClueHints,
                          used: state.currentClueHintCount,
                          isLoading: state.isRequestingClueHint,
                          onPressed: state.canRequestClueHint
                              ? context.read<GameCubit>().requestClueHint
                              : null,
                        ),
                    ],
                  ),
                ),
                clue: question.clue,
                hints: state.visibleClueHints,
                answer: WordPinInput(
                  question: question,
                  questionIndex: state.questionIndex,
                  revealedMask: state.hints.revealedMask(
                    state.room.id,
                    state.questionIndex,
                    question.letterCount,
                  ),
                  enabled: state.canEditAnswer,
                  answerController: answerController,
                  onSubmitted: onSubmitted,
                  outcome: currentResult?.outcome,
                ),
                feedback: currentResult == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AnswerFeedbackBanner(result: currentResult),
                      ),
              ),
              if (currentResult == null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Soru değeri: ${state.questionValue} puan',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
