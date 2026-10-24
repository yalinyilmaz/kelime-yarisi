import 'package:flutter/material.dart';

class SoloKeyboardActions extends StatelessWidget {
  const SoloKeyboardActions({
    required this.enabled,
    required this.onSubmit,
    required this.onClose,
    required this.letterAction,
    super.key,
  });

  final bool enabled;
  final VoidCallback onSubmit;
  final VoidCallback onClose;
  final Widget letterAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton(
          key: const ValueKey('answer-action'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: enabled ? onSubmit : null,
          child: const Text('Cevapla'),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        key: const ValueKey('close-keyboard-action'),
        tooltip: 'Klavyeyi kapat',
        onPressed: onClose,
        icon: const Icon(Icons.keyboard_hide_rounded, size: 22),
      ),
      const SizedBox(width: 8),
      Expanded(child: letterAction),
    ],
  );
}
