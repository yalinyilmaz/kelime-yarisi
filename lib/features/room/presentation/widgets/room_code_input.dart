import 'package:flutter/material.dart';

import 'room_code_formatter.dart';

class RoomCodeInput extends StatefulWidget {
  const RoomCodeInput({
    required this.onChanged,
    required this.onSubmitted,
    this.initialCode = '',
    super.key,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final String initialCode;

  @override
  State<RoomCodeInput> createState() => _RoomCodeInputState();
}

class _RoomCodeInputState extends State<RoomCodeInput> {
  late final _controller = TextEditingController.fromValue(
    const RoomCodeFormatter().formatEditUpdate(
      RoomCodeFormatter.emptyValue,
      TextEditingValue(
        text: widget.initialCode,
        selection: TextSelection.collapsed(offset: widget.initialCode.length),
      ),
    ),
  );
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const style = TextStyle(
        fontFamily: 'monospace',
        fontSize: 22,
        letterSpacing: 3,
      );
      final metrics = TextPainter(
        text: TextSpan(text: RoomCodeFormatter.emptyValue.text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final separator = metrics
          .getBoxesForSelection(
            const TextSelection(baseOffset: 3, extentOffset: 4),
          )
          .single;
      final border = Theme.of(context).inputDecorationTheme.border;
      final inputGap = border is OutlineInputBorder ? border.gapPadding : 0.0;
      final separatorCenter = (separator.left + separator.right) / 2;
      metrics.dispose();
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focusNode.requestFocus,
        child: ListenableBuilder(
          listenable: _focusNode,
          builder: (context, _) => InputDecorator(
            isFocused: _focusNode.hasFocus,
            decoration: const InputDecoration(
              labelText: 'Oda kodu',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixIcon: Icon(Icons.key_rounded),
              helperText: 'Kodu yaz veya yapıştır',
              helperMaxLines: 2,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, inputConstraints) {
                // Offset only the editable text; keep label, icon and helper
                // in their normal positions inside the decoration.
                final textInset =
                    (inputConstraints.maxWidth -
                            constraints.maxWidth / 2 +
                            16 +
                            inputGap -
                            separatorCenter)
                        .clamp(0.0, inputConstraints.maxWidth)
                        .toDouble();
                return Padding(
                  padding: EdgeInsets.only(left: textInset),
                  child: TextField(
                    key: const ValueKey('room-code-input'),
                    controller: _controller,
                    focusNode: _focusNode,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                    style: style,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    inputFormatters: const [RoomCodeFormatter()],
                    onChanged: (value) =>
                        widget.onChanged(RoomCodeFormatter.normalize(value)),
                    onSubmitted: (_) => widget.onSubmitted(),
                    decoration: null,
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
