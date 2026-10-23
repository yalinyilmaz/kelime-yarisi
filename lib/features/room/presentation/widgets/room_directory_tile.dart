import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/room_listing.dart';

class RoomDirectoryTile extends StatelessWidget {
  const RoomDirectoryTile({
    required this.room,
    required this.busy,
    required this.enabled,
    required this.onJoin,
    super.key,
  });
  final RoomListing room;
  final bool busy;
  final bool enabled;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                room.isPrivate
                    ? Icons.lock_outline_rounded
                    : Icons.public_rounded,
                color: AppColors.cyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  room.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                '${room.isPrivate ? 'Özel' : 'Açık'} oda · ${room.playerCount}/${room.capacity} oyuncu',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              FilledButton.icon(
                key: ValueKey('join-room-${room.id}'),
                onPressed: enabled && !room.isFull ? onJoin : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        room.isPrivate
                            ? Icons.lock_outline_rounded
                            : Icons.login_rounded,
                        size: 18,
                      ),
                label: Text(room.isFull ? 'Dolu' : 'Katıl'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
