import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/app_colors.dart';
import 'speech_input_cubit.dart';

class VoiceAnswerProgress extends StatelessWidget {
  const VoiceAnswerProgress({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocSelector<SpeechInputCubit, SpeechInputState, double>(
        selector: (s) => s.phase == SpeechInputPhase.listening ? s.progress : 0,
        builder: (context, progress) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: const ValueKey('voice-answer-progress'),
            minHeight: 4,
            value: progress,
            backgroundColor: AppColors.surfaceMuted,
            color: AppColors.cyan,
          ),
        ),
      );
}
