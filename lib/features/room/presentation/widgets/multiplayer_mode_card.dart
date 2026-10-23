import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MultiplayerModeCard extends StatelessWidget {
  const MultiplayerModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    enabled: onTap != null,
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outline,
          width: selected ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: selected ? AppColors.cyan : AppColors.textSecondary,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                    )
                  else
                    const Text(
                      'Yakında',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
