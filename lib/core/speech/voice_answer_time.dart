import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'speech_input_cubit.dart';

class VoiceAnswerTime extends StatelessWidget {
  const VoiceAnswerTime({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocSelector<SpeechInputCubit, SpeechInputState, String>(
        selector: (s) =>
            (SpeechInputCubit.answerDuration.inMilliseconds *
                    (1 - s.progress) /
                    1000)
                .toStringAsFixed(1)
                .replaceAll('.', ','),
        builder: (context, time) => Text(
          '$time sn',
          key: const ValueKey('voice-answer-time'),
          style: const TextStyle(fontSize: 10),
        ),
      );
}
