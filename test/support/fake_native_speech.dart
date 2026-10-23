import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/speech/speech_input_cubit.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class FakeNativeSpeech extends Fake implements SpeechToText {
  bool available = true;
  List<LocaleName> languages = [
    LocaleName('en_US', 'English'),
    LocaleName('tr_TR', 'Türkçe'),
  ];
  SpeechStatusListener? status;
  SpeechErrorListener? error;
  SpeechResultListener? result;
  SpeechListenOptions? lastOptions;
  Completer<bool>? permissionGate;
  Completer<void>? cancelGate;
  int starts = 0;
  int initializations = 0;
  bool autoReady = true;
  int stops = 0;
  int cancels = 0;
  bool bufferSupported = false;
  bool bufferActive = false;
  bool bufferArmed = false;
  int bufferPreparations = 0;
  int bufferStops = 0;
  Completer<bool>? bufferGate;

  @override
  Future<bool> prepareAudioBuffer() async {
    bufferPreparations++;
    bufferActive = bufferGate == null
        ? bufferSupported
        : await bufferGate!.future;
    return bufferActive;
  }

  @override
  Future<bool> beginAudioBuffer() async {
    bufferArmed = bufferActive;
    return bufferArmed;
  }

  @override
  Future<void> stopAudioBuffer() async {
    bufferStops++;
    bufferActive = false;
    bufferArmed = false;
  }

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    initializations++;
    error = onError;
    status = onStatus;
    return permissionGate == null ? available : permissionGate!.future;
  }

  @override
  Future<List<LocaleName>> locales() async => languages;

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    starts++;
    result = onResult;
    lastOptions = listenOptions;
    if (autoReady) status?.call(SpeechToText.listeningStatus);
  }

  void say(
    String text, {
    bool finalResult = true,
    List<String> alternatives = const [],
  }) {
    result?.call(
      SpeechRecognitionResult.init([
        for (final words in [text, ...alternatives])
          SpeechRecognitionWords(words, null, 1),
      ], finalResult ? ResultType.finalResult : ResultType.partial),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    await cancelGate?.future;
  }
}

Widget withSpeech(Widget child, {FakeNativeSpeech? recognizer}) => BlocProvider(
  key: UniqueKey(),
  create: (_) => SpeechInputCubit(recognizer: recognizer ?? FakeNativeSpeech()),
  child: child,
);
