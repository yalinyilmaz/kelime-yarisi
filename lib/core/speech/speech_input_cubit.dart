import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../monitoring/error_reporter.dart';

enum SpeechInputPhase {
  idle,
  preparing,
  ready,
  starting,
  listening,
  finalizing,
  completed,
  cancelling,
  failed,
}

class SpeechInputState {
  const SpeechInputState({
    this.phase = SpeechInputPhase.idle,
    this.transcript = '',
    this.progress = 0,
    this.error,
    this.session = 0,
    this.finalTranscripts = const [],
    this.debugTranscripts = const [],
  });

  final SpeechInputPhase phase;
  final String transcript;
  final double progress;
  final String? error;
  final int session;
  final List<String> finalTranscripts;
  final List<String> debugTranscripts;

  bool get busy => switch (phase) {
    SpeechInputPhase.preparing ||
    SpeechInputPhase.starting ||
    SpeechInputPhase.listening ||
    SpeechInputPhase.finalizing ||
    SpeechInputPhase.cancelling => true,
    _ => false,
  };
}

/// One instance per app: the native plugin retains its first status/error callbacks.
class SpeechInputCubit extends Cubit<SpeechInputState> {
  SpeechInputCubit({SpeechToText? recognizer})
    : _recognizer = recognizer ?? SpeechToText(),
      super(const SpeechInputState());

  static const answerDuration = Duration(seconds: 3);
  static const releaseTail = Duration(milliseconds: 450);
  static const finalResultTimeout = Duration(seconds: 2);
  final SpeechToText _recognizer;
  Stopwatch _clock = Stopwatch();
  Stopwatch? _bufferClock;
  Object? _audioOwner;
  bool _audioReady = false;
  Future<void> _audioWork = Future.value();
  final _startupClock = Stopwatch();
  int _cleanupMs = 0;
  int _prepareMs = 0;
  Timer? _progressTimer;
  Timer? _finalTimer;
  Timer? _startupTimer;
  Timer? _deadlineTimer;
  Timer? _settleTimer;
  Timer? _releaseTimer;
  List<String> _latestAlternatives = const [];
  bool Function(String)? _matchesAnswer;
  Future<bool>? _preparation;
  Future<dynamic>? _starting;
  Future<void> _cleanup = Future.value();
  String? _locale;
  int _session = 0;
  bool _released = false;
  bool _completing = false;

  /// Native capture only while a foreground answer widget owns the microphone.
  Future<bool> prepareAudioBuffer(Object owner) {
    _audioOwner = owner;
    final cleanup = _cleanup;
    var ready = false;
    final work = _audioWork.then((_) async {
      if (isClosed || !identical(_audioOwner, owner)) return;
      try {
        await cleanup;
        if (!await prepare() || isClosed || !identical(_audioOwner, owner)) {
          return;
        }
        await _stopAudioBuffer();
        ready = await _recognizer.prepareAudioBuffer();
        if (isClosed || !identical(_audioOwner, owner)) {
          await _recognizer.stopAudioBuffer();
          ready = false;
        } else {
          _audioReady = ready;
          if (kDebugMode) debugPrint('speech.buffer prepared=$ready');
        }
      } catch (error, stack) {
        _audioReady = false;
        ErrorReporter.report(error, stack, operation: 'speech.buffer_prepare');
        await _stopAudioBuffer();
      }
    });
    _audioWork = work;
    return work.then((_) => ready);
  }

  /// Called at tap time, before waiting for game sounds or recognizer setup.
  Future<bool> beginAudioBuffer(Object owner) async {
    if (!_audioReady || !identical(_audioOwner, owner)) return false;
    _bufferClock = Stopwatch()..start();
    try {
      final armed = await _recognizer.beginAudioBuffer();
      if (!armed) await releaseAudioBuffer(owner);
      if (kDebugMode) debugPrint('speech.buffer armed=$armed');
      return armed;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.buffer_begin');
      await releaseAudioBuffer(owner);
      return false;
    }
  }

  Future<void> releaseAudioBuffer([Object? owner]) {
    if (owner != null && !identical(_audioOwner, owner)) return Future.value();
    _audioOwner = null;
    _audioReady = false;
    return _audioWork = _audioWork.then((_) => _stopAudioBuffer());
  }

  Future<void> _stopAudioBuffer() async {
    try {
      await _recognizer.stopAudioBuffer();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.buffer_stop');
    }
  }

  Future<bool> prepare() {
    if (_locale != null) return Future.value(true);
    return _preparation ??= _prepare().whenComplete(() => _preparation = null);
  }

  Future<bool> _prepare() async {
    _publish(SpeechInputPhase.preparing);
    try {
      if (kDebugMode) debugPrint('speech.prepare initialize_begin');
      final available = await _recognizer.initialize(
        onStatus: _onStatus,
        onError: _onError,
        // We finalize the last native snapshot after the microphone is stopped.
        finalTimeout: Duration.zero,
        options: [SpeechToText.androidNoBluetooth],
      );
      if (kDebugMode) {
        debugPrint('speech.prepare initialize_done available=$available');
      }
      if (isClosed) return false;
      if (!available) {
        _fail(
          'permission-or-unavailable',
          'Sesli yanıt için mikrofon ve konuşma tanıma izni gerekiyor. '
              'İzin vermediysen telefon ayarlarından etkinleştir. '
              'Android’de konuşma tanıma hizmetinin de açık olması gerekir.',
        );
        return false;
      }
      if (kDebugMode) debugPrint('speech.prepare locales_begin');
      final locales = await _recognizer.locales();
      if (kDebugMode) {
        debugPrint('speech.prepare locales_done count=${locales.length}');
      }
      if (isClosed) return false;
      final turkish = locales
          .where(
            (locale) =>
                locale.localeId
                    .replaceAll('_', '-')
                    .toLowerCase()
                    .split('-')
                    .first ==
                'tr',
          )
          .toList();
      if (turkish.isEmpty) {
        _fail(
          'turkish-unavailable',
          'Bu cihazda Türkçe ses tanıma kullanılamıyor. '
              'Telefonun konuşma tanıma ayarlarından Türkçe desteğini etkinleştir.',
        );
        return false;
      }
      _locale = turkish
          .firstWhere(
            (locale) =>
                locale.localeId.replaceAll('_', '-').toLowerCase() == 'tr-tr',
            orElse: () => turkish.first,
          )
          .localeId;
      _publish(SpeechInputPhase.ready);
      return true;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.prepare');
      if (!isClosed) {
        _fail(
          'initialization',
          'Ses tanıma başlatılamadı. İzinlerini ve bağlantını kontrol edip tekrar dene.',
        );
      }
      return false;
    }
  }

  Future<void> start({
    List<String> contextualPhrases = const [],
    bool Function(String)? matchesAnswer,
    Future<bool>? bufferedAudio,
  }) async {
    if (isClosed || state.busy) return;
    final session = ++_session;
    final buffered = bufferedAudio != null && await bufferedAudio;
    if (isClosed || session != _session) return;
    _startupClock
      ..reset()
      ..start();
    await _cleanup;
    _cleanupMs = _startupClock.elapsedMilliseconds;
    if (!await prepare() || isClosed || session != _session) return;
    _prepareMs = _startupClock.elapsedMilliseconds - _cleanupMs;
    _released = false;
    _completing = false;
    _clock = buffered ? _bufferClock! : Stopwatch();
    _latestAlternatives = const [];
    _matchesAnswer = matchesAnswer;
    _publish(
      SpeechInputPhase.starting,
      transcript: '',
      progress: 0,
      debugTranscripts: const [],
    );
    if (buffered) _beginAnswerWindow();
    _startupTimer = Timer(const Duration(seconds: 5), () {
      if (state.phase == SpeechInputPhase.starting) {
        _fail('start-timeout', 'Mikrofon açılamadı. Tekrar dene.');
      }
    });
    try {
      _starting = _recognizer.listen(
        onResult: (result) => _onResult(session, result),
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          contextualPhrases: contextualPhrases.isEmpty
              ? null
              : contextualPhrases
                    .map((phrase) => phrase.trim())
                    .where((phrase) => phrase.isNotEmpty)
                    .toSet()
                    .take(100)
                    .toList(growable: false),
          listenFor: buffered ? null : answerDuration,
          pauseFor: buffered ? null : answerDuration,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          autoPunctuation: false,
          enableHapticFeedback: true,
          // Use the native recognizer; it may use the OS vendor's network service.
          onDevice: false,
        ),
      );
      await _starting;
      if (session != _session || isClosed) return;
      if (_released) release();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.listen');
      if (session == _session && !isClosed) {
        _fail('listen', 'Ses tanıma başlatılamadı. Tekrar dene.');
      }
    }
  }

  void _onStatus(String status) {
    if (isClosed || _completing) return;
    if (status == SpeechToText.listeningStatus &&
        state.phase == SpeechInputPhase.starting) {
      _startupTimer?.cancel();
      _startupClock.stop();
      if (kDebugMode) {
        debugPrint(
          'speech.startup cleanup_ms=$_cleanupMs '
          'prepare_ms=$_prepareMs '
          'native_ready_ms=${_startupClock.elapsedMilliseconds - _cleanupMs - _prepareMs}',
        );
      }
      _beginAnswerWindow();
      if (_released) release();
    } else if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        state.phase == SpeechInputPhase.listening) {
      unawaited(stop());
    }
  }

  void _beginAnswerWindow() {
    _clock.start();
    _publish(
      SpeechInputPhase.listening,
      progress: (_clock.elapsedMicroseconds / answerDuration.inMicroseconds)
          .clamp(0.0, 1.0),
    );
    final remaining = answerDuration - _clock.elapsed;
    _deadlineTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (state.phase != SpeechInputPhase.listening) return;
        _publish(SpeechInputPhase.listening, progress: 1);
        unawaited(stop());
      },
    );
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final progress =
          (_clock.elapsedMicroseconds / answerDuration.inMicroseconds).clamp(
            0.0,
            1.0,
          );
      _publish(SpeechInputPhase.listening, progress: progress);
      if (progress >= 1) unawaited(stop());
    });
  }

  void _onResult(int session, SpeechRecognitionResult result) {
    if (isClosed ||
        session != _session ||
        _completing ||
        ![
          SpeechInputPhase.starting,
          SpeechInputPhase.listening,
          SpeechInputPhase.finalizing,
        ].contains(state.phase)) {
      return;
    }
    final text = cleanTranscript(result.recognizedWords);
    _latestAlternatives = result.alternates
        .map((alternate) => cleanTranscript(alternate.recognizedWords))
        .where((text) => text.isNotEmpty)
        .toSet()
        .toList();
    _publish(
      state.phase,
      transcript: text,
      debugTranscripts: kDebugMode
          ? result.alternates
                .map((alternate) => alternate.recognizedWords)
                .toList()
          : const [],
    );
    final matchesAnswer = _matchesAnswer;
    if (matchesAnswer != null && _latestAlternatives.any(matchesAnswer)) {
      _completing = true;
      _matchesAnswer = null;
      _stopTimers();
      // Submit the known match now; native teardown must not delay the race.
      // The next attempt still waits for this cleanup in start().
      _cleanup = _cancelNative();
      _publish(
        SpeechInputPhase.completed,
        transcript: text,
        progress: 0,
        finalTranscripts: _latestAlternatives,
      );
    } else if (result.finalResult) {
      unawaited(_complete(text, alternatives: _latestAlternatives));
    } else if (state.phase == SpeechInputPhase.finalizing) {
      _settleSnapshot();
    }
  }

  static String cleanTranscript(String text) => text
      .replaceAll(RegExp(r'[^a-zA-ZçÇğĞıİöÖşŞüÜ\u0300-\u036f\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Keep the last syllable after finger-up, within the same three-second cap.
  void release() {
    if (isClosed) return;
    _released = true;
    if (state.phase != SpeechInputPhase.listening || _releaseTimer != null) {
      return;
    }
    _releaseTimer = Timer(releaseTail, () => unawaited(stop()));
  }

  Future<void> stop() async {
    if (isClosed) return;
    _released = true;
    if (state.phase == SpeechInputPhase.starting) return;
    if (state.phase != SpeechInputPhase.listening) return;
    _stopTimers();
    _publish(SpeechInputPhase.finalizing);
    _finalTimer = Timer(finalResultTimeout, () {
      if (state.phase != SpeechInputPhase.finalizing || _completing) return;
      unawaited(_complete(state.transcript, alternatives: _latestAlternatives));
    });
    try {
      await _recognizer.stop();
      if (!isClosed && state.phase == SpeechInputPhase.finalizing) {
        _settleSnapshot();
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.stop');
      if (!isClosed && state.phase == SpeechInputPhase.finalizing) {
        _fail('stop', 'Ses tanıma tamamlanamadı. Tekrar dene.');
      }
    }
  }

  void _settleSnapshot() {
    if (_latestAlternatives.isEmpty || _completing) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 350), () {
      if (state.phase == SpeechInputPhase.finalizing && !_completing) {
        unawaited(
          _complete(state.transcript, alternatives: _latestAlternatives),
        );
      }
    });
  }

  Future<void> _complete(
    String transcript, {
    List<String> alternatives = const [],
  }) async {
    if (_completing || isClosed) return;
    final session = _session;
    _completing = true;
    _matchesAnswer = null;
    _stopTimers();
    _publish(SpeechInputPhase.finalizing, transcript: transcript);
    try {
      await _recognizer.stop();
      if (!isClosed && session == _session) {
        _publish(SpeechInputPhase.completed, finalTranscripts: alternatives);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.complete');
      if (!isClosed && session == _session) {
        _fail('stop', 'Mikrofon kapatılamadı. Tekrar dene.');
      }
    } finally {
      _completing = false;
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (isClosed ||
        _completing ||
        ![
          SpeechInputPhase.starting,
          SpeechInputPhase.listening,
          SpeechInputPhase.finalizing,
        ].contains(state.phase)) {
      return;
    }
    if ((error.errorMsg == 'error_no_match' ||
            error.errorMsg == 'error_speech_timeout') &&
        state.phase != SpeechInputPhase.starting) {
      unawaited(_complete(''));
      return;
    }
    _fail(
      error.errorMsg,
      'Sesin anlaşılamadı veya ses tanıma hizmetine ulaşılamadı. '
      'Bağlantını ve mikrofon iznini kontrol edip tekrar dene.',
    );
  }

  void _fail(String code, String message) {
    ++_session;
    _matchesAnswer = null;
    _stopTimers();
    ErrorReporter.report(
      _SpeechFailure(code),
      StackTrace.current,
      operation: 'speech.native',
    );
    emit(
      SpeechInputState(
        phase: SpeechInputPhase.failed,
        error: message,
        session: _session,
        debugTranscripts: state.debugTranscripts,
      ),
    );
    _cleanup = _cancelNative();
  }

  Future<void> cancel({Object? audioOwner}) async {
    if (audioOwner != null && !identical(_audioOwner, audioOwner)) return;
    if (isClosed || state.phase == SpeechInputPhase.cancelling) return;
    ++_session;
    _matchesAnswer = null;
    _stopTimers();
    _publish(SpeechInputPhase.cancelling, transcript: '', progress: 0);
    final previousCleanup = _cleanup;
    final release = releaseAudioBuffer(audioOwner);
    final session = _session;
    _cleanup = (() async {
      await release;
      await previousCleanup;
      await _cancelNative();
      if (!isClosed && session == _session) {
        _publish(
          _locale == null ? SpeechInputPhase.idle : SpeechInputPhase.ready,
        );
      }
    })();
    await _cleanup;
  }

  Future<void> _cancelNative() async {
    try {
      await _starting?.timeout(const Duration(seconds: 5));
      await _recognizer.cancel().timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.cancel_native');
    }
  }

  void _stopTimers() {
    _clock.stop();
    _progressTimer?.cancel();
    _finalTimer?.cancel();
    _startupTimer?.cancel();
    _deadlineTimer?.cancel();
    _settleTimer?.cancel();
    _releaseTimer?.cancel();
    _releaseTimer = null;
  }

  void _publish(
    SpeechInputPhase phase, {
    String? transcript,
    double? progress,
    List<String> finalTranscripts = const [],
    List<String>? debugTranscripts,
  }) {
    if (!isClosed) {
      emit(
        SpeechInputState(
          phase: phase,
          transcript: transcript ?? state.transcript,
          progress: progress ?? state.progress,
          session: _session,
          finalTranscripts: finalTranscripts,
          debugTranscripts: debugTranscripts ?? state.debugTranscripts,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await cancel();
    _stopTimers();
    await super.close();
  }
}

class _SpeechFailure implements Exception, DiagnosticFailure {
  const _SpeechFailure(this.code);
  @override
  final String code;
}
