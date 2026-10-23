import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/app_colors.dart';
import '../monitoring/error_reporter.dart';
import 'speech_input_cubit.dart';
import 'voice_answer_progress.dart';
import 'voice_answer_time.dart';

Future<bool> prepareSpeechInput(BuildContext context) async {
  final speech = context.read<SpeechInputCubit>();
  final ready = await speech.prepare();
  if (!context.mounted || ready) return ready;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Türkçe sesli yanıt'),
      content: Text(speech.state.error ?? 'Ses tanıma şu anda kullanılamıyor.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
  return false;
}

class VoiceAnswerButton extends StatefulWidget {
  const VoiceAnswerButton({
    required this.enabled,
    required this.questionKey,
    required this.answerController,
    required this.onAnswer,
    required this.onMicrophoneChanged,
    this.onPrepareMicrophone,
    this.contextualPhrases = const [],
    this.matchesAnswer,
    this.letterAction,
    this.submissionFailed = false,
    this.retryFailedAttempts = true,
    super.key,
  });

  final bool enabled;
  final Object questionKey;
  final TextEditingController answerController;
  final ValueChanged<List<String>> onAnswer;
  final Future<void> Function(bool active) onMicrophoneChanged;
  final Future<void> Function()? onPrepareMicrophone;
  final List<String> contextualPhrases;
  final bool Function(String)? matchesAnswer;
  final Widget? letterAction;
  final bool submissionFailed;
  final bool retryFailedAttempts;

  @override
  State<VoiceAnswerButton> createState() => _VoiceAnswerButtonState();
}

class _VoiceAnswerButtonState extends State<VoiceAnswerButton>
    with WidgetsBindingObserver {
  late SpeechInputCubit _speech;
  late StreamSubscription<SpeechInputState> _subscription;
  Object? _questionKey;
  bool _ownsSession = false;
  bool _foreground = true;
  bool _answerStartedForQuestion = false;
  bool _answeredForQuestion = false;
  bool _showProgress = false;
  bool _hasListened = false;
  final _startupClock = Stopwatch();
  Object _audioOwner = Object();
  int _warmEpoch = 0;
  bool _warmingAudio = false;
  final _presentation = ValueNotifier((false, false, false, false, false));

  void _refreshUi() {
    _presentation.value = (
      _warmingAudio,
      _ownsSession,
      _answeredForQuestion,
      _showProgress,
      _answerStartedForQuestion,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = context.read<SpeechInputCubit>();
    _subscription = _speech.stream.listen(_onSpeech);
    _warmingAudio = widget.enabled;
    _refreshUi();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_warmAudio());
    });
  }

  @override
  void didUpdateWidget(covariant VoiceAnswerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionKey != widget.questionKey) {
      _answerStartedForQuestion = false;
      _answeredForQuestion = false;
    }
    if (widget.retryFailedAttempts &&
        widget.submissionFailed &&
        !oldWidget.submissionFailed) {
      _answeredForQuestion = false;
    }
    if (oldWidget.questionKey != widget.questionKey || !widget.enabled) {
      _cancel();
    }
    if (oldWidget.questionKey != widget.questionKey ||
        (!oldWidget.enabled && widget.enabled) ||
        (widget.retryFailedAttempts &&
            widget.submissionFailed &&
            !oldWidget.submissionFailed)) {
      _audioOwner = Object();
      unawaited(_warmAudio());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _cancel();
    } else {
      _audioOwner = Object();
      unawaited(_warmAudio());
    }
  }

  Future<void> _warmAudio() async {
    if (!widget.enabled ||
        _answeredForQuestion ||
        !_foreground ||
        _ownsSession) {
      _warmingAudio = false;
      return;
    }
    final epoch = ++_warmEpoch;
    final owner = _audioOwner;
    _warmingAudio = true;
    _refreshUi();
    try {
      await widget.onPrepareMicrophone?.call();
      if (!mounted || epoch != _warmEpoch || !_foreground) return;
      await _speech.prepareAudioBuffer(owner);
    } finally {
      if (mounted && epoch == _warmEpoch) {
        _warmingAudio = false;
        _refreshUi();
      }
    }
  }

  Future<void> _start() async {
    if (!widget.enabled ||
        _answeredForQuestion ||
        _ownsSession ||
        _speech.state.busy ||
        !_foreground) {
      return;
    }
    _ownsSession = true;
    _startupClock
      ..reset()
      ..start();
    _hasListened = false;
    _answerStartedForQuestion = true;
    _showProgress = true;
    _refreshUi();
    _questionKey = widget.questionKey;
    widget.answerController.clear();
    final buffered = _speech.beginAudioBuffer(_audioOwner);
    await widget.onMicrophoneChanged(true);
    if (kDebugMode) {
      debugPrint(
        'speech.startup audio_stop_ms=${_startupClock.elapsedMilliseconds}',
      );
    }
    if (!mounted || !_ownsSession || !widget.enabled || !_foreground) return;
    await _speech.start(
      contextualPhrases: widget.contextualPhrases,
      matchesAnswer: widget.matchesAnswer,
      bufferedAudio: buffered,
    );
  }

  void _cancel() {
    ++_warmEpoch;
    _warmingAudio = false;
    _showProgress = false;
    if (!_ownsSession) {
      unawaited(_speech.releaseAudioBuffer(_audioOwner));
      return;
    }
    _ownsSession = false;
    unawaited(_speech.cancel(audioOwner: _audioOwner));
    unawaited(widget.onMicrophoneChanged(false));
  }

  void _onSpeech(SpeechInputState state) {
    if (!mounted || !_ownsSession || _questionKey != widget.questionKey) return;
    if (state.phase == SpeechInputPhase.listening && !_hasListened) {
      _hasListened = true;
      _startupClock.stop();
      if (kDebugMode) {
        debugPrint(
          'speech.startup tap_to_ready_ms=${_startupClock.elapsedMilliseconds}',
        );
      }
      unawaited(_signalReady());
    }
    if (state.phase == SpeechInputPhase.completed ||
        state.phase == SpeechInputPhase.failed) {
      final consumed =
          state.phase == SpeechInputPhase.completed ||
          (!widget.retryFailedAttempts && _hasListened);
      _ownsSession = false;
      _showProgress = false;
      _answeredForQuestion = consumed;
      _refreshUi();
      unawaited(widget.onMicrophoneChanged(false));
      unawaited(_speech.releaseAudioBuffer(_audioOwner));
      if (consumed && widget.enabled && _foreground) {
        widget.onAnswer(
          state.phase == SpeechInputPhase.completed
              ? state.finalTranscripts
              : const [],
        );
      }
      if (!consumed && widget.enabled && _foreground) unawaited(_warmAudio());
    }
  }

  Future<void> _signalReady() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'speech.ready_haptic');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    unawaited(_subscription.cancel());
    _presentation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _presentation,
    builder: (context, _, child) => BlocBuilder<SpeechInputCubit, SpeechInputState>(
      buildWhen: (a, b) =>
          a.phase != b.phase ||
          a.error != b.error ||
          !listEquals(a.debugTranscripts, b.debugTranscripts),
      builder: (context, state) {
        final listening = state.phase == SpeechInputPhase.listening;
        final speaking = _ownsSession && _showProgress && listening;
        final waiting = _warmingAudio || (_ownsSession && !speaking);
        final canStart =
            widget.enabled &&
            !_answeredForQuestion &&
            !_ownsSession &&
            !_warmingAudio &&
            !state.busy;
        final label = speaking
            ? 'Konuş…'
            : waiting
            ? 'Bekle…'
            : 'Cevapla';
        final answer = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kDebugMode &&
                !listening &&
                state.phase != SpeechInputPhase.starting &&
                state.debugTranscripts.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: Text(
                    key: const ValueKey('voice-heard-alternatives'),
                    'Duyulanlar (debug):\n${state.debugTranscripts.map((text) => '• $text').join('\n')}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (state.error != null) ...[
              Text(
                _answeredForQuestion && !widget.retryFailedAttempts
                    ? 'Cevap alınamadı. Bu sorudaki deneme hakkın bitti.'
                    : state.error!,
                style: const TextStyle(color: AppColors.warning, fontSize: 11),
              ),
              const SizedBox(height: 6),
            ],
            if (_showProgress && _ownsSession) ...[
              const VoiceAnswerProgress(),
              const SizedBox(height: 6),
            ],
            Semantics(
              button: true,
              enabled: canStart,
              label: canStart ? 'Cevapla. Dokunup Türkçe söyle.' : label,
              // A screen-reader activation opens the same three-second window.
              onTap: canStart ? _start : null,
              child: ExcludeSemantics(
                child: FilledButton(
                  key: const ValueKey('answer-action'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: canStart ? _start : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (waiting)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.mic_rounded, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, textAlign: TextAlign.center),
                            if (speaking) ...[
                              const SizedBox(height: 4),
                              const VoiceAnswerTime(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: answer),
            if (!_answerStartedForQuestion && widget.letterAction != null) ...[
              const SizedBox(width: 12),
              Expanded(child: widget.letterAction!),
            ],
          ],
        );
      },
    ),
  );
}
