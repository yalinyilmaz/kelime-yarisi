import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/app_colors.dart';
import 'speech_input_cubit.dart';

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
  int? _pointer;
  bool _ownsSession = false;
  bool _released = false;
  bool _foreground = true;
  bool _answerStartedForQuestion = false;
  bool _answeredForQuestion = false;
  bool _showProgress = false;
  bool _hasListened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = context.read<SpeechInputCubit>();
    _subscription = _speech.stream.listen(_onSpeech);
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _cancel();
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
    _hasListened = false;
    setState(() {
      _answerStartedForQuestion = true;
      _showProgress = true;
    });
    _released = false;
    _questionKey = widget.questionKey;
    widget.answerController.clear();
    await widget.onMicrophoneChanged(true);
    if (!mounted || !_ownsSession || !widget.enabled || !_foreground) return;
    await _speech.start(
      contextualPhrases: widget.contextualPhrases,
      matchesAnswer: widget.matchesAnswer,
    );
    if (_released && mounted && _ownsSession) _speech.release();
  }

  void _stop() {
    _pointer = null;
    _released = true;
    setState(() => _showProgress = false);
    if (_ownsSession) _speech.release();
  }

  void _cancel() {
    _pointer = null;
    _released = true;
    _showProgress = false;
    if (!_ownsSession) return;
    _ownsSession = false;
    unawaited(_speech.cancel());
    unawaited(widget.onMicrophoneChanged(false));
  }

  void _onSpeech(SpeechInputState state) {
    if (!mounted || !_ownsSession || _questionKey != widget.questionKey) return;
    if (state.phase == SpeechInputPhase.listening) _hasListened = true;
    if (state.phase == SpeechInputPhase.completed ||
        state.phase == SpeechInputPhase.failed) {
      final consumed =
          state.phase == SpeechInputPhase.completed ||
          (!widget.retryFailedAttempts && _hasListened);
      _ownsSession = false;
      _pointer = null;
      setState(() {
        _showProgress = false;
        _answeredForQuestion = consumed;
      });
      unawaited(widget.onMicrophoneChanged(false));
      if (consumed && widget.enabled && _foreground) {
        widget.onAnswer(
          state.phase == SpeechInputPhase.completed
              ? state.finalTranscripts
              : const [],
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SpeechInputCubit, SpeechInputState>(
    builder: (context, state) {
      final listening = state.phase == SpeechInputPhase.listening;
      final speaking = _ownsSession && _showProgress && listening;
      final waiting = _ownsSession && !speaking;
      final canStart =
          widget.enabled &&
          !_answeredForQuestion &&
          !_ownsSession &&
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
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const ValueKey('voice-answer-progress'),
                minHeight: 4,
                value: listening ? state.progress : 0,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.cyan,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Semantics(
            button: true,
            enabled: canStart,
            label: canStart ? 'Cevapla. Basılı tutup Türkçe söyle.' : label,
            // A screen-reader activation opens the same three-second window.
            onTap: canStart ? _start : null,
            child: Listener(
              onPointerDown: (event) {
                if (_pointer != null || !canStart) return;
                _pointer = event.pointer;
                unawaited(_start());
              },
              onPointerUp: (event) {
                if (_pointer == event.pointer) _stop();
              },
              onPointerCancel: (event) {
                if (_pointer == event.pointer) _cancel();
              },
              child: ExcludeSemantics(
                child: FilledButton(
                  key: const ValueKey('answer-action'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: canStart ? () {} : null,
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
                            const SizedBox(height: 4),
                            if (speaking)
                              Text(
                                '${(SpeechInputCubit.answerDuration.inMilliseconds * (1 - state.progress) / 1000).toStringAsFixed(1).replaceAll('.', ',')} sn',
                                key: const ValueKey('voice-answer-time'),
                                style: const TextStyle(fontSize: 10),
                              )
                            else if (canStart)
                              const Text(
                                'Basılı tut',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
  );
}
