import 'game_letter_action.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/speech/voice_answer_button.dart';
import '../cubit/game_audio_cubit.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';

class GameActions extends StatelessWidget {
  const GameActions({
    super.key,
    required this.state,
    required this.onSubmit,
    required this.answerController,
  });

  final GameState state;
  final VoidCallback onSubmit;
  final TextEditingController answerController;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: VoiceAnswerButton(
      enabled: state.canAct,
      submissionFailed: state.errorMessage != null,
      retryFailedAttempts: false,
      questionKey: (state.room.id, state.questionIndex),
      answerController: answerController,
      matchesAnswer: (text) => state.question?.answerInSpeech(text) != null,
      contextualPhrases: [
        if (state.question != null) ...[
          state.question!.answer,
          ...state.question!.acceptedAnswers,
        ],
      ],
      onMicrophoneChanged: context.read<GameAudioCubit>().setSpeechListening,
      onPrepareMicrophone: context.read<GameAudioCubit>().prepareMicrophone,
      onAnswer: (transcripts) {
        final game = context.read<GameCubit>();
        if (!game.state.canAct ||
            game.state.questionIndex != state.questionIndex) {
          return;
        }
        final matched = transcripts.any(
          (text) => state.question!.answerInSpeech(text) != null,
        );
        final answer = matched ? state.question!.answer : null;
        if (answer == null) {
          game.submitAnswer('', questionIndex: state.questionIndex);
        } else {
          answerController.text = answer;
          onSubmit();
        }
      },
      letterAction: const GameLetterAction(),
    ),
  );
}
