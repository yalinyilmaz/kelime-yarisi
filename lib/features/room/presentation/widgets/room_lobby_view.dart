import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../game/presentation/widgets/game_confirmation_dialogs.dart';
import '../../data/firebase_room_service.dart';
import '../../domain/entities/game_room.dart';
import '../../domain/entities/room_player.dart';
import '../cubit/room_lobby_cubit.dart';
import '../cubit/room_lobby_state.dart';
import '../widgets/room_code_card.dart';
import '../widgets/room_countdown_card.dart';
import '../widgets/room_empty_player_tile.dart';
import '../widgets/room_player_tile.dart';
import 'question_capacity_card.dart';

class RoomLobbyView extends StatefulWidget {
  const RoomLobbyView({super.key});

  @override
  State<RoomLobbyView> createState() => _RoomLobbyViewState();
}

class _RoomLobbyViewState extends State<RoomLobbyView> {
  bool _confirmingLeave = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomLobbyCubit, RoomLobbyState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.room.status != current.room.status,
      listener: (context, state) {
        if (state.room.status == RoomStatus.playing ||
            state.room.status == RoomStatus.results) {
          context.go('/game/${state.room.id}', extra: state.room);
          return;
        }
        final message = state.errorMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        context.read<RoomLobbyCubit>().clearError();
      },
      builder: (context, state) {
        final room = state.room;
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
          canPop: false,
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
                          RoomCodeCard(room: room),
                          if (kDebugMode &&
                              (state.isLoadingQuestionCapacity ||
                                  state.questionCapacity != null)) ...[
                            const SizedBox(height: 16),
                            if (state.isLoadingQuestionCapacity)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text('Soru havuzu yükleniyor…'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              QuestionCapacityCard(
                                capacity: state.questionCapacity!,
                                collective: state.collectiveCapacity,
                              ),
                          ],
                          if (room.status == RoomStatus.countdown) ...[
                            const SizedBox(height: 16),
                            RoomCountdownCard(
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
                            (player) => RoomPlayerTile(
                              player: player,
                              isCurrent: player.id == currentUserId,
                            ),
                          ),
                          ...List.generate(
                            (room.targetPlayerCount - room.players.length)
                                .clamp(0, 6),
                            (_) => const RoomEmptyPlayerTile(),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                                currentPlayer == null ||
                                    room.status != RoomStatus.lobby ||
                                    state.isStartingGame ||
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
                            icon: Icon(
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
                          if (room.hostId == currentUserId) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed:
                                  context.read<RoomLobbyCubit>().canStartGame
                                  ? context.read<RoomLobbyCubit>().startGame
                                  : null,
                              icon: state.isStartingGame
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow_rounded),
                              label: const Text('Oyunu Başlat'),
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
    if (_confirmingLeave || cubit.isClosed || cubit.state.isLeaving) return;
    _confirmingLeave = true;
    try {
      final confirmed = await GameConfirmationDialogs.leave(
        context,
        isHost:
            cubit.state.room.hostId ==
            context.read<FirebaseRoomService>().currentUserId,
        onLeave: () async {
          await cubit.leaveRoom();
          return !cubit.isClosed && cubit.state.isLeaving
              ? null
              : cubit.state.errorMessage ?? 'Odadan çıkılamadı. Tekrar dene.';
        },
      );
      if (confirmed && context.mounted) context.go('/multiplayer/rooms');
    } finally {
      _confirmingLeave = false;
    }
  }

  String _statusText(GameRoom room) {
    return switch (room.status) {
      RoomStatus.lobby when room.players.length < 2 && !kDebugMode =>
        'Oyunun başlaması için en az 2 oyuncu gerekli.',
      RoomStatus.lobby when !room.everyoneIsReady =>
        'Oyuncuların hazır olması bekleniyor.',
      RoomStatus.lobby => 'Oda sahibinin oyunu başlatması bekleniyor.',
      RoomStatus.countdown => 'Tüm cihazlar aynı sunucu saatini kullanıyor.',
      RoomStatus.playing => 'Yarışma başladı.',
      RoomStatus.results => 'Sonuçlar hazır.',
    };
  }
}
