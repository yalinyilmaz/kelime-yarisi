import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/speech/speech_input_cubit.dart';
import 'package:kelime_yarisi/core/speech/voice_answer_button.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'support/fake_native_speech.dart';

void main() {
  testWidgets(
    'new question waits for old cancellation without retaining its microphone',
    (tester) async {
      final native = FakeNativeSpeech()
        ..bufferSupported = true
        ..bufferGate = Completer<bool>();
      final speech = SpeechInputCubit(recognizer: native);
      await speech.prepare();
      final first = Object(), next = Object();
      final oldWarm = speech.prepareAudioBuffer(first);
      await tester.pump();
      final cancel = speech.cancel(audioOwner: first);
      final newWarm = speech.prepareAudioBuffer(next);
      native.bufferGate!.complete(true);
      expect(await oldWarm, isFalse);
      await cancel;
      expect(await newWarm, isTrue);
      await speech.releaseAudioBuffer(first);
      expect(native.bufferActive, isTrue);
      await speech.close();
      expect(native.bufferActive, isFalse);
    },
  );

  testWidgets(
    'buffer ownership rejects stale preparation and stale screen cleanup',
    (tester) async {
      final native = FakeNativeSpeech()..bufferSupported = true;
      final speech = SpeechInputCubit(recognizer: native);
      final first = Object(), second = Object();
      await speech.prepare();
      native.bufferGate = Completer<bool>();
      final preparing = speech.prepareAudioBuffer(first);
      await tester.pump();
      expect(native.bufferPreparations, 1);
      final stopping = speech.releaseAudioBuffer(first);
      native.bufferGate!.complete(true);
      expect(await preparing, isFalse);
      await stopping;
      expect(native.bufferActive, isFalse);
      native.bufferGate = null;
      expect(await speech.prepareAudioBuffer(second), isTrue);
      final stops = native.bufferStops;
      await speech.releaseAudioBuffer(first);
      expect(native.bufferStops, stops);
      expect(native.bufferActive, isTrue);
      await speech.close();
      expect(native.bufferActive, isFalse);
    },
  );

  testWidgets(
    'buffered capture has one three-second window even before recognizer readiness',
    (tester) async {
      final native = FakeNativeSpeech()
        ..bufferSupported = true
        ..autoReady = false;
      final speech = SpeechInputCubit(recognizer: native);
      final owner = Object();
      await speech.prepareAudioBuffer(owner);
      await speech.start(bufferedAudio: speech.beginAudioBuffer(owner));
      expect(speech.state.phase, SpeechInputPhase.listening);
      expect(native.lastOptions!.listenFor, isNull);
      expect(native.lastOptions!.pauseFor, isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(speech.state.phase, SpeechInputPhase.finalizing);
      expect(native.stops, 1);
      native.status!(SpeechToText.listeningStatus);
      await tester.pump();
      expect(speech.state.phase, SpeechInputPhase.finalizing);
      native.say('bilek');
      await tester.pump();
      expect(speech.state.finalTranscripts, ['bilek']);
      await speech.close();
    },
  );

  testWidgets(
    'tap arms buffered audio before waiting for game sound shutdown',
    (tester) async {
      final native = FakeNativeSpeech()
        ..bufferSupported = true
        ..autoReady = false;
      final speech = SpeechInputCubit(recognizer: native);
      final answer = TextEditingController();
      final silence = Completer<void>();
      await tester.pumpWidget(
        BlocProvider.value(
          value: speech,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceAnswerButton(
                enabled: true,
                questionKey: 0,
                answerController: answer,
                onAnswer: (_) {},
                onMicrophoneChanged: (active) async {
                  if (active) await silence.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(native.bufferActive, isTrue);
      await tester.tap(find.byKey(const ValueKey('answer-action')));
      await tester.pump();
      expect(native.bufferArmed, isTrue);
      expect(native.starts, 0);
      silence.complete();
      await tester.pump();
      expect(native.starts, 1);
      expect(find.text('Konuş…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await speech.close();
      expect(native.bufferActive, isFalse);
      answer.dispose();
    },
  );

  testWidgets(
    'idle pre-roll closes in background and resets at question boundaries',
    (tester) async {
      final native = FakeNativeSpeech()..bufferSupported = true;
      final speech = SpeechInputCubit(recognizer: native);
      final answer = TextEditingController();
      Future<void> mount(int key, {bool enabled = true}) => tester.pumpWidget(
        BlocProvider.value(
          value: speech,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceAnswerButton(
                enabled: enabled,
                questionKey: key,
                answerController: answer,
                onAnswer: (_) {},
                onMicrophoneChanged: (_) async {},
              ),
            ),
          ),
        ),
      );
      await mount(0);
      await tester.pumpAndSettle();
      expect(native.bufferActive, isTrue);
      await mount(1);
      await tester.pumpAndSettle();
      expect(native.bufferPreparations, 2);
      expect(native.bufferArmed, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(native.bufferActive, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(native.bufferActive, isTrue);
      await mount(1, enabled: false);
      await tester.pumpAndSettle();
      expect(native.bufferActive, isFalse);
      await tester.pumpWidget(const SizedBox());
      await speech.close();
      answer.dispose();
    },
  );

  test(
    'plugin listen timer begins at native readiness, not request acceptance',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var stops = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'stop') stops++;
        return true;
      });
      final recognizer = SpeechToText.withMethodChannel();
      try {
        expect(await recognizer.initialize(), isTrue);
        await recognizer.listen(
          listenOptions: SpeechListenOptions(
            listenFor: const Duration(milliseconds: 40),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(stops, 0);
        final ready = Completer<void>();
        ServicesBinding.instance.channelBuffers.push(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('notifyStatus', 'listening'),
          ),
          (_) => ready.complete(),
        );
        await ready.future;
        expect(recognizer.isListening, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(stops, 1);
      } finally {
        await recognizer.cancel();
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );

  testWidgets('preparation is cached and does not open the microphone', (
    tester,
  ) async {
    final native = FakeNativeSpeech();
    final speech = SpeechInputCubit(recognizer: native);
    expect(await speech.prepare(), isTrue);
    expect(await speech.prepare(), isTrue);
    expect(native.initializations, 1);
    expect(native.starts, 0);
    await speech.start();
    expect(native.initializations, 1);
    expect(native.lastOptions!.localeId, 'tr_TR');
    expect(native.lastOptions!.enableHapticFeedback, isTrue);
    await speech.close();
  });

  testWidgets(
    'talk cue, vibration and three-second clock wait for native readiness',
    (tester) async {
      final native = FakeNativeSpeech()..autoReady = false;
      final speech = SpeechInputCubit(recognizer: native);
      final answer = TextEditingController();
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await speech.prepare();
      await tester.pumpWidget(
        BlocProvider.value(
          value: speech,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceAnswerButton(
                enabled: true,
                questionKey: 0,
                answerController: answer,
                onAnswer: (_) {},
                onMicrophoneChanged: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('answer-action')));
      await tester.pump(const Duration(seconds: 2));
      expect(speech.state.phase, SpeechInputPhase.starting);
      expect(find.text('Konuş…'), findsNothing);
      expect(haptics, isEmpty);
      expect(native.stops, 0);
      native.status!(SpeechToText.listeningStatus);
      await tester.pump();
      expect(find.text('Konuş…'), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      native.status!(SpeechToText.listeningStatus);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(haptics, hasLength(1));
      expect(native.stops, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(speech.state.phase, SpeechInputPhase.finalizing);
      expect(native.stops, 1);
      await tester.pumpWidget(const SizedBox());
      await speech.close();
      answer.dispose();
    },
  );

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
    'matching interim alternative completes before slow native cancellation',
    (tester) async {
      final gate = Completer<void>();
      final native = FakeNativeSpeech()..cancelGate = gate;
      final speech = SpeechInputCubit(recognizer: native);
      const question = GameQuestion(clue: '', answer: 'GÖNDERMEK');
      await speech.start(
        matchesAnswer: (text) => question.answerInSpeech(text) != null,
      );
      await tester.pump(const Duration(milliseconds: 300));
      native.say('gönder', finalResult: false);
      expect(speech.state.phase, SpeechInputPhase.listening);
      expect(speech.state.finalTranscripts, isEmpty);
      native.say(
        'yanlış duyulan',
        finalResult: false,
        alternatives: ['cevap göndermektir'],
      );
      expect(speech.state.phase, SpeechInputPhase.completed);
      expect(speech.state.progress, 0);
      expect(speech.state.finalTranscripts, [
        'yanlış duyulan',
        'cevap göndermektir',
      ]);
      await tester.pump();
      expect(native.cancels, 1);
      expect(gate.isCompleted, isFalse);
      native.say('geç sonuç');
      native.error!(SpeechRecognitionError('error_no_match', true));
      speech.release();
      await tester.pump(const Duration(seconds: 3));
      expect(speech.state.phase, SpeechInputPhase.completed);
      expect(speech.state.finalTranscripts.last, 'cevap göndermektir');
      final next = speech.start();
      await tester.pump();
      expect(native.starts, 1);
      gate.complete();
      await next;
      expect(native.starts, 2);
      await speech.close();
    },
  );

  testWidgets('unmatched interim speech keeps the existing timeout flow', (
    tester,
  ) async {
    final native = FakeNativeSpeech();
    final speech = SpeechInputCubit(recognizer: native);
    const question = GameQuestion(clue: '', answer: 'BİLEK');
    await speech.start(
      matchesAnswer: (text) => question.answerInSpeech(text) != null,
    );
    native.say('bilmiyorum', finalResult: false);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(speech.state.phase, SpeechInputPhase.listening);
    expect(native.cancels, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(speech.state.phase, SpeechInputPhase.finalizing);
    await tester.pump(const Duration(milliseconds: 350));
    expect(speech.state.phase, SpeechInputPhase.completed);
    expect(speech.state.finalTranscripts, ['bilmiyorum']);
    await speech.close();
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
    'one tap keeps listening and expands the answer area until completion',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      final answer = TextEditingController();
      Future<void> mount(int question, {bool submissionFailed = false}) =>
          tester.pumpWidget(
            BlocProvider.value(
              value: speech,
              child: MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 360,
                    child: VoiceAnswerButton(
                      enabled: true,
                      questionKey: question,
                      submissionFailed: submissionFailed,
                      answerController: answer,
                      onAnswer: (_) {},
                      onMicrophoneChanged: (_) async {},
                      letterAction: OutlinedButton(
                        key: const ValueKey('hint-action'),
                        onPressed: () {},
                        child: const Text('Harf Al'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      final button = find.byKey(const ValueKey('answer-action'));
      final letters = find.byKey(const ValueKey('hint-action'));
      final progress = find.byKey(const ValueKey('voice-answer-progress'));
      await mount(0);
      await tester.pumpAndSettle();
      expect(letters, findsOneWidget);
      expect(progress, findsNothing);
      expect(find.text('Basılı tut'), findsNothing);
      expect(tester.getSize(button).width, 174);
      await tester.tap(button);
      await tester.pump();
      expect(speech.state.phase, SpeechInputPhase.listening);
      expect(letters, findsNothing);
      expect(tester.getSize(button).width, 360);
      expect(tester.getSize(progress).width, 360);
      expect(find.byKey(const ValueKey('voice-answer-time')), findsOneWidget);
      await tester.tap(button);
      await tester.pump(SpeechInputCubit.releaseTail);
      expect(native.starts, 1);
      expect(native.stops, 0);
      expect(progress, findsOneWidget);
      expect(speech.state.phase, SpeechInputPhase.listening);
      native.error!(SpeechRecognitionError('error_network', true));
      await tester.pump();
      expect(letters, findsNothing);
      await tester.tap(button);
      await tester.pump();
      native.say('cevap');
      await tester.pump();
      expect(speech.state.phase, SpeechInputPhase.completed);
      expect(letters, findsNothing);
      expect(progress, findsNothing);
      expect(find.text('Basılı tut'), findsNothing);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await mount(0, submissionFailed: true);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(letters, findsNothing);
      expect(progress, findsNothing);
      await mount(1);
      await tester.pumpAndSettle();
      expect(letters, findsOneWidget);
      expect(progress, findsNothing);
      expect(find.text('Basılı tut'), findsNothing);
      expect(tester.getSize(button).width, 174);
      await tester.pumpWidget(const SizedBox());
      await speech.close();
      answer.dispose();
    },
  );

  testWidgets(
    'matching speech submits after a tap and resets progress; background cancels',
    (tester) async {
      final native = FakeNativeSpeech();
      final speech = SpeechInputCubit(recognizer: native);
      final answer = TextEditingController();
      final submitted = <List<String>>[];
      final microphone = <bool>[];
      Future<void> mount(int question) => tester.pumpWidget(
        BlocProvider.value(
          value: speech,
          child: MaterialApp(
            home: Scaffold(
              body: VoiceAnswerButton(
                enabled: true,
                questionKey: question,
                answerController: answer,
                matchesAnswer: (text) =>
                    const GameQuestion(
                      clue: '',
                      answer: 'GÖNDERMEK',
                    ).answerInSpeech(text) !=
                    null,
                onAnswer: submitted.add,
                onMicrophoneChanged: (active) async => microphone.add(active),
              ),
            ),
          ),
        ),
      );
      await mount(0);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('answer-action')));
      await tester.pump();
      native.say('gönder', finalResult: false);
      await tester.pump();
      expect(answer.text, isEmpty);
      expect(submitted, isEmpty);
      native.say('cevap göndermektir', finalResult: false);
      await tester.pump();
      expect(submitted, [
        ['cevap göndermektir'],
      ]);
      expect(microphone, [true, false]);
      expect(find.byKey(const ValueKey('voice-answer-progress')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('answer-action')))
            .onPressed,
        isNull,
      );
      native.say('göndermek');
      await tester.pump();
      expect(submitted, hasLength(1));
      await mount(1);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('answer-action')));
      await tester.pump();
      expect(native.starts, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      native.say('geç cevap');
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
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('answer-action')));
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
      await tester.pumpWidget(const SizedBox());
      await speech.close();
      answer.dispose();
    },
  );
}
