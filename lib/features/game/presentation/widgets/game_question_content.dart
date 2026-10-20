import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'game_clue_hints.dart';

/// Scrolls the existing question card into view without moving its answer field.
class GameQuestionContent extends StatefulWidget {
  const GameQuestionContent({
    required this.questionIndex,
    required this.header,
    required this.clue,
    required this.hints,
    required this.answer,
    super.key,
  });

  final int questionIndex;
  final Widget header;
  final String clue;
  final List<String> hints;
  final Widget answer;

  @override
  State<GameQuestionContent> createState() => _GameQuestionContentState();
}

class _GameQuestionContentState extends State<GameQuestionContent>
    with WidgetsBindingObserver {
  final _sectionKey = GlobalKey();
  final _clueKey = GlobalKey();
  final _answerKey = GlobalKey();
  bool _hasFocus = false;
  bool _visibilityScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() => _scheduleVisibility();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleVisibility();
  }

  @override
  void didUpdateWidget(covariant GameQuestionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionIndex != widget.questionIndex) _scheduleVisibility();
  }

  void _scheduleVisibility() {
    if (_visibilityScheduled) return;
    _visibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityScheduled = false;
      // Scaffold removes the keyboard inset from its resized body's MediaQuery.
      if (!mounted || !_hasFocus || View.of(context).viewInsets.bottom <= 0) {
        return;
      }
      _revealQuestion();
    });
  }

  void _revealQuestion() {
    final position = Scrollable.maybeOf(context)?.position;
    final answer = _answerKey.currentContext?.findRenderObject();
    final clue = _clueKey.currentContext?.findRenderObject();
    final section = _sectionKey.currentContext?.findRenderObject();
    if (position == null ||
        !position.hasContentDimensions ||
        answer is! RenderBox ||
        !answer.hasSize ||
        clue is! RenderBox ||
        !clue.hasSize ||
        section is! RenderBox ||
        !section.hasSize) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(answer);
    if (viewport == null) return;

    final bottom = viewport.getOffsetToReveal(answer, 1).offset + 12;
    final sectionTop = viewport.getOffsetToReveal(section, 0).offset - 12;
    final clueTop = viewport.getOffsetToReveal(clue, 0).offset - 12;
    // Include the header when it fits. Otherwise prioritize clue → hints → PIN.
    // For exceptionally long text, keep the full PIN visible and allow scrolling.
    final top = bottom <= sectionTop ? sectionTop : clueTop;
    final target = (bottom <= top ? position.pixels.clamp(bottom, top) : bottom)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 1) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(target);
    } else {
      unawaited(
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleVisibility();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: Column(
            key: _sectionKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.header,
              const SizedBox(height: 12),
              Padding(
                key: _clueKey,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.clue,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              GameClueHints(hints: widget.hints),
              const SizedBox(height: 24),
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onFocusChange: (focused) {
                  _hasFocus = focused;
                  if (focused) _scheduleVisibility();
                },
                child: SizedBox(key: _answerKey, child: widget.answer),
              ),
            ],
          ),
        ),
      );
}
