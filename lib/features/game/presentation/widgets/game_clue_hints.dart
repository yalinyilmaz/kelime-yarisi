import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class GameClueHintButton extends StatelessWidget {
  const GameClueHintButton({
    required this.remaining,
    required this.used,
    this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final int remaining;
  final int used;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (remaining <= 0) return const SizedBox.shrink();
    final enabled = onPressed != null && !isLoading;
    return TextFieldTapRegion(
      child: Tooltip(
        message: 'İpucu · Bu soruda $used/2 kullanıldı',
        child: FilledButton.icon(
          key: const ValueKey('clue-hint-action'),
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.warning.withValues(alpha: 0.16),
            foregroundColor: AppColors.warning,
            disabledBackgroundColor: AppColors.surfaceMuted,
            disabledForegroundColor: AppColors.textSecondary,
            minimumSize: const Size(36, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: enabled
                  ? AppColors.warning.withValues(alpha: 0.45)
                  : AppColors.outline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.warning,
                  ),
                )
              : const Icon(Icons.lightbulb_rounded, size: 16),
          label: Text('İpucu al  $remaining'),
        ),
      ),
    );
  }
}

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
