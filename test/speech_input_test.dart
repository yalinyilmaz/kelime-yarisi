import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/speech/speech_input_cubit.dart';
import 'package:kelime_yarisi/core/speech/voice_answer_button.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'support/fake_native_speech.dart';

void main() {
  test('voice contains ignores spaces, Turkish case, filler and suffixes', () {
    const question = GameQuestion(clue: '', answer: 'GÖNDERMEK');
    expect(
      question.answerInSpeech(' Bir düşüneyim, cevap göndermektir. '),
      'GÖNDERMEK',
    );
    expect(question.answerInSpeech('g o n d e r m e k'), 'GÖNDERMEK');
    expect(question.answerInSpeech('getirmektir'), isNull);
    const phrase = GameQuestion(clue: '', answer: 'EL FENERİ');
    expect(phrase.answerInSpeech('bence elfeneridir'), 'EL FENERİ');
    expect(phrase.answerInSpeech('el'), isNull);
    const alias = GameQuestion(
      clue: '',
      answer: 'HEKİM',
      acceptedAnswers: ['DOKTOR'],
    );
    expect(alias.answerInSpeech('doktor olabilir'), 'HEKİM');
  });

  testWidgets(
    'Turkish answer vocabulary biases recognition without replacing native text',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      await speech.start(
        contextualPhrases: [' BİLEK ', 'BİLEK', '', 'EL BİLEĞİ'],
      );
      expect(native.lastOptions!.localeId, 'tr_TR');
      expect(native.lastOptions!.contextualPhrases, ['BİLEK', 'EL BİLEĞİ']);
      native.say('black');
      await tester.pump();
      expect(speech.state.finalTranscripts, ['black']);
      const question = GameQuestion(clue: '', answer: 'BİLEK');
      expect(question.answerInSpeech('black'), isNull);
      expect(question.answerInSpeech('bilek'), 'BİLEK');
      await speech.close();
    },
  );

  testWidgets(
    'Turkish is explicit; partials stay uncommitted; final alternatives are retained',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      await speech.start();
      expect(native.lastOptions!.localeId, 'tr_TR');
      expect(native.lastOptions!.contextualPhrases, isNull);
      native.say('gönder', finalResult: false);
      expect(speech.state.phase, SpeechInputPhase.listening);
      expect(speech.state.finalTranscripts, isEmpty);
      native.say('göndermektir', alternatives: ['göndermek']);
      await tester.pump();
      expect(speech.state.phase, SpeechInputPhase.completed);
      expect(speech.state.finalTranscripts, ['göndermektir', 'göndermek']);
      await speech.close();
    },
  );

  testWidgets('finger-up keeps the microphone open for the last syllable', (
    tester,
  ) async {
    final native = FakeNativeSpeech();
    final speech = SpeechInputCubit(recognizer: native);
    await speech.start();
    native.say('yap', finalResult: false);
    speech.release();
    await tester.pump(const Duration(milliseconds: 449));
    expect(native.stops, 0);
    expect(speech.state.phase, SpeechInputPhase.listening);
    native.say('yapmak', finalResult: false);
    expect(speech.state.finalTranscripts, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(native.stops, 1);
    expect(speech.state.phase, SpeechInputPhase.finalizing);
    await tester.pump(const Duration(milliseconds: 350));
    expect(speech.state.phase, SpeechInputPhase.completed);
    expect(speech.state.finalTranscripts, ['yapmak']);
    await speech.close();
  });

  testWidgets('release tail never extends the three-second limit', (
    tester,
  ) async {
    final native = FakeNativeSpeech();
    final speech = SpeechInputCubit(recognizer: native);
    await speech.start();
    await tester.pump(const Duration(milliseconds: 2800));
    speech.release();
    await tester.pump(const Duration(milliseconds: 200));
    expect(native.stops, 1);
    expect(speech.state.phase, SpeechInputPhase.finalizing);
    expect(speech.state.progress, 1);
    await tester.pump(SpeechInputCubit.releaseTail);
    expect(native.stops, 1);
    await speech.close();
  });

  testWidgets('cancellation clears the release timer before another attempt', (
    tester,
  ) async {
    final native = FakeNativeSpeech();
    final speech = SpeechInputCubit(recognizer: native);
    await speech.start();
    speech.release();
    await tester.pump(const Duration(milliseconds: 200));
    await speech.cancel();
    await speech.start();
    await tester.pump(SpeechInputCubit.releaseTail);
    expect(native.stops, 0);
    expect(speech.state.phase, SpeechInputPhase.listening);
    speech.release();
    await speech.close();
    await tester.pump(SpeechInputCubit.releaseTail);
    expect(native.stops, 0);
  });

  testWidgets(
    'microphone stops at three seconds; late final can still resolve that attempt',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      await speech.start();
      await tester.pump(const Duration(seconds: 3));
      expect(speech.state.phase, SpeechInputPhase.finalizing);
      expect(native.stops, 1);
      expect(speech.state.progress, 1);
      native.say('cevap göndermektir');
      await tester.pump();
      expect(speech.state.phase, SpeechInputPhase.completed);
      await speech.close();
    },
  );

  testWidgets(
    'no speech consumes the attempt; native/network errors do not complete it',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      await speech.start();
      await tester.pump(const Duration(seconds: 5));
      expect(speech.state.phase, SpeechInputPhase.completed);
      expect(speech.state.finalTranscripts, isEmpty);
      await speech.start();
      native.error!(SpeechRecognitionError('error_network', true));
      await tester.pump();
      expect(speech.state.phase, SpeechInputPhase.failed);
      expect(speech.state.finalTranscripts, isEmpty);
      await speech.close();
    },
  );

  testWidgets(
    'cancelling rejects old callbacks; stopped snapshot resolves without a native final flag',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      await speech.start();
      final old = native.result!;
      await speech.cancel();
      await speech.start();
      native.say('gönder', finalResult: false);
      final current = native.result;
      native.result = old;
      native.say('göndermektir');
      native.result = current;
      expect(speech.state.phase, SpeechInputPhase.listening);
      await speech.stop();
      await tester.pump(SpeechInputCubit.finalResultTimeout);
      expect(speech.state.phase, SpeechInputPhase.completed);
      expect(speech.state.finalTranscripts, ['gönder']);
      await speech.close();
    },
  );

  testWidgets(
    'permission denial or missing Turkish never falls back to English',
    (tester) async {
      final denied = SpeechInputCubit(
        recognizer: FakeNativeSpeech()..available = false,
      );
      expect(await denied.prepare(), isFalse);
      expect(denied.state.error, contains('mikrofon'));
      await denied.close();
      final native = FakeNativeSpeech()
        ..languages = [LocaleName('en_US', 'English')];
      final speech = SpeechInputCubit(recognizer: native);
      expect(await speech.prepare(), isFalse);
      expect(native.starts, 0);
      await speech.close();
    },
  );

  testWidgets(
    'cancel while permission is pending never starts recording afterwards',
    (tester) async {
      final native = FakeNativeSpeech()..permissionGate = Completer<bool>();
      final speech = SpeechInputCubit(recognizer: native);
      final start = speech.start();
      await tester.pump();
      await speech.cancel();
      native.permissionGate!.complete(true);
      await start;
      expect(native.starts, 0);
      await speech.close();
    },
  );

  testWidgets(
    'hold has no partial PIN updates; release submits once; background cancels',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      final answer = TextEditingController();
      final submitted = <List<String>>[];
      final microphone = <bool>[];
      await tester.pumpWidget(
        BlocProvider.value(
          value: speech,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceAnswerButton(
                enabled: true,
                questionKey: 0,
                answerController: answer,
                onAnswer: submitted.add,
                onMicrophoneChanged: (active) async => microphone.add(active),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('answer-action'))),
      );
      await tester.pump();
      native.say('gönder', finalResult: false);
      await tester.pump();
      expect(answer.text, isEmpty);
      expect(submitted, isEmpty);
      await gesture.up();
      await tester.pump();
      native.say('cevap göndermektir');
      await tester.pump();
      expect(submitted, [
        ['cevap göndermektir'],
      ]);
      expect(microphone, [true, false]);
      final next = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('answer-action'))),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      native.say('geç cevap');
      await next.up();
      await tester.pump();
      expect(submitted, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await speech.close();
      answer.dispose();
    },
  );

  testWidgets(
    'debug failure shows every heard alternative without submitting',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      final answer = TextEditingController();
      final submitted = <List<String>>[];
      await tester.pumpWidget(
        BlocProvider.value(
          value: speech,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceAnswerButton(
                enabled: true,
                questionKey: 0,
                answerController: answer,
                onAnswer: submitted.add,
                onMicrophoneChanged: (_) async {},
              ),
            ),
          ),
        ),
      );
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('answer-action'))),
      );
      await tester.pump();
      native.say(
        'cevap göndermektir',
        finalResult: false,
        alternatives: ['göndermek', 'bir düşüneyim'],
      );
      native.error!(SpeechRecognitionError('error_network', true));
      await tester.pump();
      final diagnostic = tester
          .widget<Text>(find.byKey(const ValueKey('voice-heard-alternatives')))
          .data!;
      expect(diagnostic, contains('cevap göndermektir'));
      expect(diagnostic, contains('göndermek'));
      expect(diagnostic, contains('bir düşüneyim'));
      expect(submitted, isEmpty);
      expect(answer.text, isEmpty);
      await hold.up();
      await tester.pumpWidget(const SizedBox());
      await speech.close();
      answer.dispose();
    },
  );
}
