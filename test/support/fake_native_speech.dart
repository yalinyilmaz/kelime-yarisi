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
  int stops = 0;
  int cancels = 0;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
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
    status?.call(SpeechToText.listeningStatus);
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
