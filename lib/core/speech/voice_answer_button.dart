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
    super.key,
  });

  final bool enabled;
  final Object questionKey;
  final TextEditingController answerController;
  final ValueChanged<List<String>> onAnswer;
  final Future<void> Function(bool active) onMicrophoneChanged;
  final List<String> contextualPhrases;

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
    if (!widget.enabled || _ownsSession || _speech.state.busy || !_foreground) {
      return;
    }
    _ownsSession = true;
    _released = false;
    _questionKey = widget.questionKey;
    widget.answerController.clear();
    await widget.onMicrophoneChanged(true);
    if (!mounted || !_ownsSession || !widget.enabled || !_foreground) return;
    await _speech.start(contextualPhrases: widget.contextualPhrases);
    if (_released && mounted && _ownsSession) _speech.release();
  }

  void _stop() {
    _pointer = null;
    _released = true;
    if (_ownsSession) _speech.release();
  }

  void _cancel() {
    _pointer = null;
    _released = true;
    if (!_ownsSession) return;
    _ownsSession = false;
    unawaited(_speech.cancel());
    unawaited(widget.onMicrophoneChanged(false));
  }

  void _onSpeech(SpeechInputState state) {
    if (!mounted || !_ownsSession || _questionKey != widget.questionKey) return;
    if (state.phase == SpeechInputPhase.completed ||
        state.phase == SpeechInputPhase.failed) {
      _ownsSession = false;
      _pointer = null;
      unawaited(widget.onMicrophoneChanged(false));
      if (state.phase == SpeechInputPhase.completed &&
          widget.enabled &&
          _foreground) {
        widget.onAnswer(state.finalTranscripts);
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
      final waiting = state.busy && !listening;
      final label = listening
          ? 'Konuş…'
          : waiting
          ? 'Bekle…'
          : 'Cevapla';
      return Column(
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
              state.error!,
              style: const TextStyle(color: AppColors.warning, fontSize: 11),
            ),
            const SizedBox(height: 6),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const ValueKey('voice-answer-progress'),
              minHeight: 4,
              value: listening || state.phase == SpeechInputPhase.finalizing
                  ? state.progress
                  : 0,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.cyan,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            enabled: widget.enabled && !state.busy,
            label: 'Cevapla. Basılı tutup Türkçe söyle. En fazla üç saniye.',
            // A screen-reader activation opens the same three-second window.
            onTap: widget.enabled && !state.busy ? _start : null,
            child: Listener(
              onPointerDown: (event) {
                if (_pointer != null || !widget.enabled || state.busy) return;
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
                child: FilledButton.icon(
                  key: const ValueKey('answer-action'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: widget.enabled && !state.busy ? () {} : null,
                  icon: waiting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mic_rounded, size: 20),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      if (!state.busy)
                        const Text(
                          'Basılı tut · 3 sn',
                          style: TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
