import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/speech/voice_answer_button.dart';
import '../cubit/solo_game_cubit.dart';
import '../cubit/solo_game_state.dart';

class SoloGameActions extends StatelessWidget {
  const SoloGameActions({
    required this.state,
    required this.onSubmit,
    required this.answerController,
    super.key,
  });
  final SoloGameState state;
  final VoidCallback onSubmit;
  final TextEditingController answerController;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: VoiceAnswerButton(
            enabled: state.canAct,
            questionKey: (state.set?.id, state.questionIndex),
            answerController: answerController,
            contextualPhrases: [
              if (state.question != null) ...[
                state.question!.answer,
                ...state.question!.acceptedAnswers,
              ],
            ],
            onMicrophoneChanged: context
                .read<SoloGameCubit>()
                .setSpeechListening,
            onAnswer: (transcripts) {
              final game = context.read<SoloGameCubit>();
              if (!game.state.canAct ||
                  game.state.questionIndex != state.questionIndex) {
                return;
              }
              final matched = transcripts.any(
                (text) => state.question!.answerInSpeech(text) != null,
              );
              final answer = matched ? state.question!.answer : null;
              if (answer == null) {
                game.giveUp(state.questionIndex);
              } else {
                answerController.text = answer;
                onSubmit();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('hint-action'),
            onPressed: state.canRevealLetter
                ? context.read<SoloGameCubit>().revealLetter
                : null,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
            label: const Text('Harf Al'),
          ),
        ),
      ],
    ),
  );
}
