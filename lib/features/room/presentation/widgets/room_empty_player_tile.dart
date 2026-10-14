import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RoomEmptyPlayerTile extends StatelessWidget {
  const RoomEmptyPlayerTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.outline),
                ),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.outline,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Oyuncu bekleniyor…',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
