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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: VoiceAnswerButton(
            enabled: state.canAct,
            questionKey: (state.room.id, state.questionIndex),
            answerController: answerController,
            contextualPhrases: [
              if (state.question != null) ...[
                state.question!.answer,
                ...state.question!.acceptedAnswers,
              ],
            ],
            onMicrophoneChanged: context
                .read<GameAudioCubit>()
                .setSpeechListening,
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
                game.giveUp(questionIndex: state.questionIndex);
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
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: state.canVote
                ? context.read<GameCubit>().revealLetter
                : null,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Harf Al'),
                Text(
                  state.isVoting
                      ? 'Kaydediliyor…'
                      : state.hasVoted
                      ? 'Oy verdin · 1/${state.room.requiredHintVotes}'
                      : '${state.hints.firstVoterId == null ? 0 : 1}/${state.room.requiredHintVotes} oy',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
