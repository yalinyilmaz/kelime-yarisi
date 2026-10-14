import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RoomCountdownCard extends StatelessWidget {
  const RoomCountdownCard({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ready),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.ready),
              SizedBox(width: 8),
              Text(
                'HERKES HAZIR',
                style: TextStyle(
                  color: AppColors.ready,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$seconds',
            style: Theme.of(context).textTheme.displayLarge
                ?.copyWith(color: AppColors.textPrimary, fontSize: 54),
          ),
        ],
      ),
    );
  }
}
