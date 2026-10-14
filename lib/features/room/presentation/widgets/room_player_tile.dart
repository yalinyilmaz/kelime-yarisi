import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/room_player.dart';

class RoomPlayerTile extends StatelessWidget {
  const RoomPlayerTile({
    super.key,
    required this.player,
    required this.isCurrent,
  });

  final RoomPlayer player;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColor(player.id);
    final statusColor = player.isReady
        ? AppColors.ready
        : player.isOnline
        ? AppColors.textSecondary
        : AppColors.danger;
    final statusIcon = player.isReady
        ? Icons.check_circle_rounded
        : player.isOnline
        ? Icons.schedule_rounded
        : Icons.cloud_off_rounded;
    final statusText = player.isReady
        ? 'Hazır'
        : player.isOnline
        ? 'Bekliyor'
        : 'Çevrimdışı';

    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.surfaceMuted : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.surfaceMuted,
        ),
      ),
      child: ListTile(
        minTileHeight: 66,
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          foregroundColor: avatarColor == AppColors.warning
              ? AppColors.onWarning
              : AppColors.textPrimary,
          child: Text(
            player.displayName.isEmpty
                ? '?'
                : player.displayName.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          isCurrent ? '${player.displayName} (Sen)' : player.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: player.isHost
            ? const Text(
                'Oda sahibi',
                style: TextStyle(color: AppColors.textSecondary),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(String id) {
    const colors = [AppColors.primary, AppColors.violet, AppColors.warning];
    return colors[id.hashCode.abs() % colors.length];
  }
}
