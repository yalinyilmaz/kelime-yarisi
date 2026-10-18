import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/game_progress.dart';
import '../../domain/game_question.dart';
import 'word_letter_cell.dart';
import 'word_letter_formatter.dart';

class WordPinInput extends StatefulWidget {
  const WordPinInput({
    required this.question,
    required this.questionIndex,
    required this.revealedMask,
    required this.enabled,
    required this.answerController,
    required this.onSubmitted,
    this.outcome,
    super.key,
  });

  final AnswerOutcome? outcome;
  final GameQuestion question;
  final int questionIndex;
  final int revealedMask;
  final bool enabled;
  final TextEditingController answerController;
  final VoidCallback onSubmitted;

  @override
  State<WordPinInput> createState() => _WordPinInputState();
}

class _WordPinInputState extends State<WordPinInput>
    with AutomaticKeepAliveClientMixin {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Animation<double>? _routeAnimation;
  int? _focusedQuestion;
  bool _focusScheduled = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_inputChanged);
    _focus.addListener(_focusChanged);
    if (widget.outcome != null) _fillAnswer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleFocus();
  }

  void _inputChanged() {
    _publishAnswer();
    setState(() {});
  }

  void _focusChanged() => setState(() {});

  void _routeStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_routeStatusChanged);
      _routeAnimation = null;
      _scheduleFocus();
    }
  }

  void _scheduleFocus() {
    if (!widget.enabled ||
        _focusScheduled ||
        _focusedQuestion == widget.questionIndex) {
      return;
    }
    _focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScheduled = false;
      if (!mounted ||
          !widget.enabled ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final animation = ModalRoute.of(context)?.animation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        if (_routeAnimation != animation) {
          _routeAnimation?.removeStatusListener(_routeStatusChanged);
          _routeAnimation = animation;
          animation.addStatusListener(_routeStatusChanged);
        }
        return;
      }
      _focusedQuestion = widget.questionIndex;
      _focus.requestFocus();
    });
  }

  void _setText(String text) {
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  bool get wantKeepAlive => true;

  List<int> _hiddenPositions(int mask) => [
    for (var i = 0; i < widget.question.letterCount; i++)
      if ((mask & (1 << i)) == 0) i,
  ];

  @override
  void didUpdateWidget(covariant WordPinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionIndex != widget.questionIndex) {
      _setText('');
      _publishAnswer();
    } else if (oldWidget.revealedMask != widget.revealedMask) {
      final previousPositions = _hiddenPositions(oldWidget.revealedMask);
      final typed = _text.text;
      _setText(
        [
          for (var i = 0; i < typed.length && i < previousPositions.length; i++)
            if ((widget.revealedMask & (1 << previousPositions[i])) == 0)
              typed[i],
        ].join(),
      );
      _publishAnswer();
    }
    if (widget.outcome != null &&
        (oldWidget.outcome != widget.outcome ||
            oldWidget.questionIndex != widget.questionIndex)) {
      _fillAnswer();
    }
    _scheduleFocus();
  }

  void _fillAnswer() {
    _setText(
      _hiddenPositions(widget.revealedMask)
          .map((i) => widget.question.letters[i])
          .join(),
    );
    widget.answerController.text = widget.question.answer;
  }

  void _publishAnswer() {
    if (widget.outcome != null) {
      widget.answerController.text = widget.question.answer;
      return;
    }
    var inputIndex = 0;
    final answer = StringBuffer();
    for (var i = 0; i < widget.question.letterCount; i++) {
      if ((widget.revealedMask & (1 << i)) != 0) {
        answer.write(widget.question.letters[i]);
      } else {
        if (inputIndex < _text.text.length) {
          answer.write(_text.text[inputIndex]);
        }
        inputIndex++;
      }
    }
    widget.answerController.text = answer.toString();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeStatusChanged);
    _text.removeListener(_inputChanged);
    _focus.removeListener(_focusChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hiddenPositions = _hiddenPositions(widget.revealedMask);
    final focusedIndex = _text.text.length < hiddenPositions.length
        ? _text.text.length
        : hiddenPositions.length - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.question.letterCount;
        final spacing =
            ((constraints.maxWidth - count * 32) / math.max(1, count - 1))
                .clamp(3.0, 6.0)
                .toDouble();
        final cellWidth = math.min(
          32.0,
          (constraints.maxWidth - spacing * (count - 1)) / count,
        );
        return Stack(
          children: [
            IgnorePointer(
              child: Row(
                spacing: spacing,
                children: [
                  for (var i = 0; i < count; i++)
                    WordLetterCell(
                      key: ValueKey('${widget.questionIndex}-$i'),
                      width: cellWidth,
                      index: i,
                      outcome: widget.outcome,
                      character:
                          widget.outcome != null ||
                              (widget.revealedMask & (1 << i)) != 0
                          ? widget.question.letters[i]
                          : hiddenPositions.indexOf(i) < _text.text.length
                          ? _text.text[hiddenPositions.indexOf(i)]
                          : null,
                      revealed: (widget.revealedMask & (1 << i)) != 0,
                      focused:
                          widget.enabled &&
                          _focus.hasFocus &&
                          hiddenPositions.indexOf(i) == focusedIndex,
                    ),
                ],
              ),
            ),
            // A normal-sized native field owns one stable keyboard connection.
            // Transparent text preserves PIN visuals without a tiny/offstage editable.
            Positioned.fill(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                // Dismiss on release so keyboard resizing cannot move a button
                // away from the finger before its tap completes.
                onTapOutside: (_) {},
                onTapUpOutside: (_) => _focus.unfocus(),
                readOnly: !widget.enabled && !_focus.hasFocus,
                showCursor: false,
                enableInteractiveSelection: false,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                scrollPadding: EdgeInsets.zero,
                style: const TextStyle(color: Colors.transparent, fontSize: 20),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                inputFormatters: [
                  if (!widget.enabled)
                    TextInputFormatter.withFunction((oldValue, _) => oldValue),
                  WordLetterFormatter(widget.question, hiddenPositions),
                  LengthLimitingTextInputFormatter(hiddenPositions.length),
                ],
                onEditingComplete: () {},
                onSubmitted: (_) {
                  if (widget.enabled) widget.onSubmitted();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
