import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RoomJoinInfo extends StatelessWidget {
  const RoomJoinInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.cyan),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aynı oda kodunu kullanan herkes, kendi cihazından aynı oyuna katılır.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
