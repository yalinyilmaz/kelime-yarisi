import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class GameClueHintButton extends StatelessWidget {
  const GameClueHintButton({
    required this.remaining,
    required this.used,
    this.onPressed,
    super.key,
  });

  final int remaining;
  final int used;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (remaining <= 0) return const SizedBox.shrink();
    final enabled = onPressed != null;
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
          icon: const Icon(Icons.lightbulb_rounded, size: 16),
          label: Text('İpucu al  $remaining'),
        ),
      ),
    );
  }
}
