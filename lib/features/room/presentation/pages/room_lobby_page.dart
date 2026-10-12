import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
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
        RoomPlayer? currentPlayer;
        final currentUserId = context.read<FirebaseRoomService>().currentUserId;
        for (final player in room.players) {
          if (player.id == currentUserId) {
            currentPlayer = player;
            break;
          }
        }

        return PopScope(
          canPop: state.isLeaving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leaveAndPop(context);
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                onPressed: state.isLeaving ? null : () => _leaveAndPop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(room.name),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _RoomCodeCard(room: room),
                if (room.status == RoomStatus.countdown) ...[
                  const SizedBox(height: 16),
                  _CountdownCard(seconds: state.countdownSeconds ?? 0),
                ],
                if (room.status == RoomStatus.playing) ...[
                  const SizedBox(height: 16),
                  const _GameReadyCard(),
                ],
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Oyuncular',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${room.players.length}/${room.targetPlayerCount}',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...room.players.map((player) => _PlayerTile(player: player)),
                ...List.generate(
                  (room.targetPlayerCount - room.players.length).clamp(0, 5),
                  (_) => const _EmptyPlayerTile(),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      currentPlayer == null ||
                          room.status != RoomStatus.lobby ||
                          state.isLeaving
                      ? null
                      : context.read<RoomLobbyCubit>().toggleCurrentPlayerReady,
                  style: FilledButton.styleFrom(
                    backgroundColor: currentPlayer?.isReady == true
                        ? AppColors.ink
                        : AppColors.blue,
                  ),
                  icon: state.isLeaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Icon(
                          currentPlayer?.isReady == true
                              ? Icons.undo_rounded
                              : Icons.check_circle_outline_rounded,
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
                const SizedBox(height: 12),
                Text(
                  _statusText(room),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
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
      RoomStatus.lobby => 'Herkes hazır olduğunda oyun otomatik başlayacak.',
      RoomStatus.countdown => 'Tüm cihazlar aynı sunucu saatini kullanıyor.',
      RoomStatus.playing => 'Canlı oda doğrulandı. Sıradaki adım oyun ekranı.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'ODA KODU',
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            room.code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${room.gameMode.label} · ${room.gameMode.description}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
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
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'HERKES HAZIR',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$seconds',
            style: const TextStyle(
              color: AppColors.blueDark,
              fontSize: 54,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameReadyCard extends StatelessWidget {
  const _GameReadyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.rocket_launch_rounded, color: AppColors.blueDark),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Oyun başladı. Soru ve puan motoru Step 3’te bu akışa bağlanacak.',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player});

  final RoomPlayer player;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surface,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.mint,
              foregroundColor: AppColors.ink,
              child: Text(
                player.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: player.isOnline ? Colors.green : AppColors.muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          player.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          player.isHost
              ? 'Oda sahibi'
              : player.isOnline
              ? 'Çevrimiçi'
              : 'Bağlantı kesildi',
        ),
        trailing: Text(
          player.isReady ? 'Hazır' : 'Bekliyor',
          style: TextStyle(
            color: player.isReady ? AppColors.blue : AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyPlayerTile extends StatelessWidget {
  const _EmptyPlayerTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: AppColors.muted),
          SizedBox(width: 12),
          Text('Oyuncu bekleniyor…', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
