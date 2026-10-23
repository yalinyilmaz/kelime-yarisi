import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelime_yarisi/core/speech/speech_input_cubit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native pre-roll captures, attaches and releases before reopening',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Ses tamponu cihaz kontrolü')),
          ),
        ),
      );
      final speech = SpeechInputCubit();
      final owner = Object();
      try {
        expect(
          await speech.prepare().timeout(const Duration(seconds: 20)),
          isTrue,
        );
        expect(
          await speech
              .prepareAudioBuffer(owner)
              .timeout(const Duration(seconds: 8)),
          isTrue,
          reason: 'This device test requires iOS or Android 13+ audio-source support.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final buffered = speech.beginAudioBuffer(owner);
        expect(await buffered, isTrue);
        await speech.start(bufferedAudio: buffered);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        expect(
          speech.state.phase,
          isNot(SpeechInputPhase.failed),
          reason: speech.state.error,
        );
        await speech.cancel(audioOwner: owner);
        expect(speech.state.phase, SpeechInputPhase.ready);
        expect(
          await speech
              .prepareAudioBuffer(Object())
              .timeout(const Duration(seconds: 8)),
          isTrue,
          reason: 'The prior microphone/recognizer must release successfully.',
        );
        await speech.releaseAudioBuffer();
        // ignore: avoid_print
        print('SPEECH_BUFFER_NATIVE_CAPTURE_ATTACH_REOPEN=passed');
      } finally {
        await speech.close();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
