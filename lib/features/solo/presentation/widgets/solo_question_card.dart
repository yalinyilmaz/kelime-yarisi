import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../game/presentation/widgets/answer_feedback_banner.dart';
import '../../../game/presentation/widgets/game_clue_hints.dart';
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
          Padding(
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              state.question!.clue,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          GameClueHints(hints: state.visibleHints),
          const SizedBox(height: 24),
          WordPinInput(
            question: state.question!,
            questionIndex: state.questionIndex,
            revealedMask: state.revealedMask,
            enabled: state.canAct,
            answerController: answerController,
            onSubmitted: onSubmit,
            outcome: state.feedback?.outcome,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: state.feedback == null
                ? Text(
                    'Soru değeri: ${state.questionValue} puan',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : AnswerFeedbackBanner(result: state.feedback!),
          ),
        ],
      ),
    ),
  );
}
