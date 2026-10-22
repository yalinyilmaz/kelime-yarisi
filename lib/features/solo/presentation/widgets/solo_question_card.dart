import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../game/presentation/widgets/answer_feedback_banner.dart';
import '../../../game/presentation/widgets/game_clue_hints.dart';
import '../../../game/presentation/widgets/game_question_content.dart';
import '../../../game/presentation/widgets/word_pin_input.dart';
import '../cubit/solo_game_cubit.dart';
import '../cubit/solo_game_state.dart';

class SoloQuestionCard extends StatelessWidget {
  const SoloQuestionCard({
    required this.state,
    required this.answerController,
    required this.onSubmit,
    super.key,
  });
  final SoloGameState state;
  final TextEditingController answerController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Card(
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
                      'SORU ${state.questionIndex + 1} / 14',
                    ),
                  ),
                  GameClueHintButton(
                    remaining: state.remainingHints,
                    used: state.currentHintCount,
                    onPressed: state.canRequestHint
                        ? context.read<SoloGameCubit>().requestHint
                        : null,
                  ),
                ],
              ),
            ),
            clue: state.question!.clue,
            hints: state.visibleHints,
            answer: WordPinInput(
              voiceOnly: true,
              question: state.question!,
              questionIndex: state.questionIndex,
              revealedMask: state.revealedMask,
              enabled: state.canAct,
              answerController: answerController,
              onSubmitted: onSubmit,
              outcome: state.feedback?.outcome,
            ),
            feedback: state.feedback == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnswerFeedbackBanner(result: state.feedback!),
                  ),
          ),
          if (state.feedback == null) ...[
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
}
