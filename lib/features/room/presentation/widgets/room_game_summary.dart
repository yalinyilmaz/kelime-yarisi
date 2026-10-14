import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/room_game_mode.dart';

class RoomGameSummary extends StatelessWidget {
  const RoomGameSummary({super.key, required this.mode});

  final RoomGameMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.onPaper),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${mode.duration.inMinutes} dakika · Aynı soru seti · Canlı skor',
              style: const TextStyle(
                color: AppColors.onPaper,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
