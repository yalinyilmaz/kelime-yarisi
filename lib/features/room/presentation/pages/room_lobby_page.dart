import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../game/presentation/pages/game_page.dart';
import '../../data/firebase_room_service.dart';
import '../../domain/entities/game_room.dart';
import '../../domain/entities/room_player.dart';
import '../cubit/room_lobby_cubit.dart';
import '../cubit/room_lobby_state.dart';

class RoomLobbyPage extends StatelessWidget {
  const RoomLobbyPage({required this.room, super.key});

  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoomLobbyCubit(context.read<FirebaseRoomService>(), room),
      child: const _RoomLobbyView(),
    );
  }
}

class _RoomLobbyView extends StatelessWidget {
  const _RoomLobbyView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomLobbyCubit, RoomLobbyState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        context.read<RoomLobbyCubit>().clearError();
      },
      builder: (context, state) {
        final room = state.room;
        if (room.status == RoomStatus.playing ||
            room.status == RoomStatus.results) {
          return GamePage(room: room);
        }
        final currentUserId = context.read<FirebaseRoomService>().currentUserId;
        RoomPlayer? currentPlayer;
        for (final player in room.players) {
          if (player.id == currentUserId) {
            currentPlayer = player;
            break;
          }
        }
        final readyCount = room.players
            .where((player) => player.isReady)
            .length;

        return PopScope(
          canPop: state.isLeaving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leaveAndPop(context);
          },
          child: NightStudioScaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: 'Odadan çık',
                onPressed: state.isLeaving ? null : () => _leaveAndPop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(room.name),
            ),
            body: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gutter = constraints.maxWidth <= 360 ? 20.0 : 24.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
                        children: [
                          _RoomCodeCard(room: room),
                          if (room.status == RoomStatus.countdown) ...[
                            const SizedBox(height: 16),
                            _CountdownCard(
                              seconds: state.countdownSeconds ?? 0,
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Oyuncular ${room.players.length}/${room.targetPlayerCount}',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.ready,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$readyCount hazır',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...room.players.map(
                            (player) => _PlayerTile(
                              player: player,
                              isCurrent: player.id == currentUserId,
                            ),
                          ),
                          ...List.generate(
                            (room.targetPlayerCount - room.players.length)
                                .clamp(0, 6),
                            (_) => const _EmptyPlayerTile(),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                                currentPlayer == null ||
                                    room.status != RoomStatus.lobby ||
                                    state.isLeaving
                                ? null
                                : context
                                      .read<RoomLobbyCubit>()
                                      .toggleCurrentPlayerReady,
                            style: FilledButton.styleFrom(
                              backgroundColor: currentPlayer?.isReady == true
                                  ? AppColors.surfaceMuted
                                  : AppColors.ready,
                              foregroundColor: currentPlayer?.isReady == true
                                  ? AppColors.textPrimary
                                  : AppColors.onReady,
                            ),
                            icon: state.isLeaving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Icon(
                                    currentPlayer?.isReady == true
                                        ? Icons.undo_rounded
                                        : Icons.check_rounded,
                                  ),
                            label: Text(switch (room.status) {
                              RoomStatus.lobby =>
                                currentPlayer?.isReady == true
                                    ? 'Hazır Değilim'
                                    : 'Hazırım',
                              RoomStatus.countdown => 'Oyun başlıyor',
                              RoomStatus.playing => 'Oyun başladı',
                              RoomStatus.results => 'Oyun tamamlandı',
                            }),
                          ),
                          if (kDebugMode && room.hostId == currentUserId) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed:
                                  room.status == RoomStatus.lobby &&
                                      !state.isLeaving
                                  ? context
                                        .read<RoomLobbyCubit>()
                                        .startDebugGame
                                  : null,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Oyunu Başlat · Debug'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            _statusText(room),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _leaveAndPop(BuildContext context) async {
    final cubit = context.read<RoomLobbyCubit>();
    await cubit.leaveRoom();
    if (context.mounted && cubit.state.isLeaving) {
      Navigator.of(context).pop();
    }
  }

  String _statusText(GameRoom room) {
    return switch (room.status) {
      RoomStatus.lobby when room.players.length < room.targetPlayerCount =>
        'Odanın dolması bekleniyor.',
      RoomStatus.lobby => 'Herkes hazır olduğunda 3–2–1 başlar.',
      RoomStatus.countdown => 'Tüm cihazlar aynı sunucu saatini kullanıyor.',
      RoomStatus.playing => 'Yarışma başladı.',
      RoomStatus.results => 'Sonuçlar hazır.',
    };
  }
}

class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({required this.room});

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
          IconButton.filledTonal(
            tooltip: 'Oda kodunu kopyala',
            onPressed: () => _copyCode(context),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              backgroundColor: AppColors.paperMuted,
              foregroundColor: AppColors.onPaper,
            ),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: room.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Oda kodu kopyalandı.')));
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.seconds});

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

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.isCurrent});

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

class _EmptyPlayerTile extends StatelessWidget {
  const _EmptyPlayerTile();

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
