import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/speech/speech_input_cubit.dart';
import '../../../../core/speech/voice_answer_button.dart';
import '../cubit/solo_game_cubit.dart';
import '../cubit/solo_game_state.dart';
import 'solo_keyboard_actions.dart';

class SoloGameActions extends StatelessWidget {
  const SoloGameActions({
    required this.state,
    required this.onSubmit,
    required this.answerController,
    required this.keyboardMode,
    required this.onKeyboardModeChanged,
    super.key,
  });
  final SoloGameState state;
  final VoidCallback onSubmit;
  final TextEditingController answerController;
  final bool keyboardMode;
  final ValueChanged<bool> onKeyboardModeChanged;

  @override
  Widget build(BuildContext context) {
    final letterAction = OutlinedButton.icon(
      key: const ValueKey('hint-action'),
      onPressed: state.canRevealLetter
          ? context.read<SoloGameCubit>().revealLetter
          : null,
      icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
      label: const Text('Harf Al'),
    );
    return TextFieldTapRegion(
      child: keyboardMode
          ? SoloKeyboardActions(
              enabled: state.canAct,
              onSubmit: onSubmit,
              onClose: () => onKeyboardModeChanged(false),
              letterAction: letterAction,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BlocSelector<SpeechInputCubit, SpeechInputState, bool>(
                      selector: (speech) => speech.busy,
                      builder: (context, busy) => IconButton(
                        key: const ValueKey('open-keyboard-action'),
                        tooltip: 'Klavyeyle cevapla',
                        onPressed: state.canAct && !busy
                            ? () => onKeyboardModeChanged(true)
                            : null,
                        icon: const Icon(Icons.keyboard_rounded, size: 22),
                      ),
                    ),
                  ],
                ),
                VoiceAnswerButton(
                  enabled: state.canAct,
                  submissionFailed: state.errorMessage != null,
                  questionKey: (state.set?.id, state.questionIndex),
                  answerController: answerController,
                  matchesAnswer: (text) =>
                      state.question?.answerInSpeech(text) != null,
                  contextualPhrases: [
                    if (state.question != null) ...[
                      state.question!.answer,
                      ...state.question!.acceptedAnswers,
                    ],
                  ],
                  onMicrophoneChanged: context
                      .read<SoloGameCubit>()
                      .setSpeechListening,
                  onPrepareMicrophone: context
                      .read<SoloGameCubit>()
                      .prepareMicrophone,
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
                      game.submitAnswer('', questionIndex: state.questionIndex);
                    } else {
                      answerController.text = answer;
                      onSubmit();
                    }
                  },
                  letterAction: letterAction,
                ),
              ],
            ),
    );
  }
}
