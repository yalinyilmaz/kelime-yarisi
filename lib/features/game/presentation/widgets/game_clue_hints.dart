import 'package:flutter/material.dart';

class GameClueHints extends StatelessWidget {
  const GameClueHints({required this.hints, super.key});

  final List<String> hints;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 220),
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: hints.isEmpty
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(hints.join('\n')),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  for (var i = 0; i < hints.length; i++)
                    Text(
                      '${i + 1}. ${hints[i]}',
                      style: TextStyle(color: Colors.amber.shade100),
                    ),
                ],
              ),
            ),
    ),
  );
}
