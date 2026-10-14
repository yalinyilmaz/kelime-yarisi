import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/game_question.dart';

class WordPinInput extends StatefulWidget {
  const WordPinInput({
    required this.question,
    required this.questionIndex,
    required this.revealedMask,
    required this.enabled,
    required this.answerController,
    required this.onSubmitted,
    super.key,
  });

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
    _scheduleFocus();
  }

  void _publishAnswer() {
    var inputIndex = 0;
    final answer = StringBuffer();
    for (var i = 0; i < widget.question.letterCount; i++) {
      if ((widget.revealedMask & (1 << i)) != 0) {
        answer.write(widget.question.answer[i]);
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
    return Stack(
      children: [
        IgnorePointer(
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.question.letterCount; i++)
                _LetterCell(
                  character: (widget.revealedMask & (1 << i)) != 0
                      ? widget.question.answer[i]
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
            readOnly: !widget.enabled,
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
              _WordLetterFormatter(widget.question, hiddenPositions),
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
  }
}

class _WordLetterFormatter extends TextInputFormatter {
  _WordLetterFormatter(this.question, this.hiddenPositions);

  final GameQuestion question;
  final List<int> hiddenPositions;

  String _formatLetters(String input) {
    final text = GameQuestion.normalizeAnswer(input)
        .replaceAll(RegExp('[^A-ZÇĞİÖŞÜ]'), '');
    return [
      for (var i = 0; i < text.length; i++)
        i < hiddenPositions.length
            ? question.normalizeLetter(text[i], hiddenPositions[i])
            : text[i],
    ].join();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final text = _formatLetters(newValue.text);
    final prefix = newValue.selection.extentOffset < 0
        ? newValue.text
        : newValue.text.substring(0, newValue.selection.extentOffset);
    final offset = _formatLetters(prefix).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class _LetterCell extends StatelessWidget {
  const _LetterCell({
    required this.character,
    required this.revealed,
    required this.focused,
  });
  final String? character;
  final bool revealed;
  final bool focused;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: revealed ? AppColors.paper : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: focused ? AppColors.cyan : Colors.transparent,
        width: 2,
      ),
    ),
    child: Text(
      character ?? (focused ? '│' : '·'),
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: revealed ? AppColors.onPaper : AppColors.textPrimary,
      ),
    ),
  );
}
