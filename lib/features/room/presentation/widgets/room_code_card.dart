import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/game_room.dart';
import '../cubit/room_lobby_cubit.dart';

class RoomCodeCard extends StatelessWidget {
  const RoomCodeCard({super.key, required this.room});

  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ODA KODU',
                  style: TextStyle(
                    color: AppColors.onPaper,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    room.code,
                    style: const TextStyle(
                      color: AppColors.onPaper,
                      fontSize: 36,
                      height: 1.11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${room.gameMode.label} · ${room.gameMode.description}',
                  style: const TextStyle(
                    color: AppColors.onPaper,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (buttonContext) => IconButton.filledTonal(
              tooltip: 'Oda kodunu kopyala ve paylaş',
              onPressed: () {
                final box = buttonContext.findRenderObject()! as RenderBox;
                buttonContext.read<RoomLobbyCubit>().copyAndShareCode(
                  box.localToGlobal(Offset.zero) & box.size,
                );
              },
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                backgroundColor: AppColors.paperMuted,
                foregroundColor: AppColors.onPaper,
              ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
