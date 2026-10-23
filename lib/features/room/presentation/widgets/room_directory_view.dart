import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/profile/player_name_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../domain/entities/game_room.dart';
import '../../domain/entities/room_listing.dart';
import '../cubit/room_directory_cubit.dart';
import 'room_directory_tile.dart';
import 'private_room_dialog.dart';

class RoomDirectoryView extends StatefulWidget {
  const RoomDirectoryView({super.key});
  @override
  State<RoomDirectoryView> createState() => _RoomDirectoryViewState();
}

class _RoomDirectoryViewState extends State<RoomDirectoryView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<RoomDirectoryCubit>();
    if (state == AppLifecycleState.resumed &&
        !cubit.state.loading &&
        !cubit.state.joining) {
      cubit.load();
    }
  }

  Future<void> _load() => context.read<RoomDirectoryCubit>().load();

  Future<void> _join(RoomListing listing) async {
    final cubit = context.read<RoomDirectoryCubit>();
    if (!cubit.beginJoin(listing)) return;
    try {
      final name = context.read<PlayerNameCubit>().state!;
      final room = listing.isPrivate
          ? await showDialog<GameRoom>(
              context: context,
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: PrivateRoomDialog(listing: listing, displayName: name),
              ),
            )
          : await cubit.join(listing, name);
      if (room == null) return;
      if (!mounted) {
        await cubit.releaseJoinedRoom(room);
        return;
      }
      context.go('/room/${room.id}', extra: room);
    } finally {
      // Keep public join failures visible; closing a private dialog clears its error.
      if (!cubit.isClosed) cubit.finishJoin(clearError: listing.isPrivate);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RoomDirectoryCubit, RoomDirectoryState>(
        builder: (context, state) => NightStudioScaffold(
          appBar: AppBar(
            title: const Text('Odalar'),
            actions: [
              IconButton(
                tooltip: 'Listeyi yenile',
                onPressed: state.loading || state.joining ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Oda oluştur',
                onPressed: state.joining ? null : () => context.push('/create'),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (!state.loading && !state.joining) await _load();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      const Text(
                        'Sağ üstteki + ile oda oluştur veya açık bir odaya doğrudan katıl. Kilitli odalar için oda kodunu gir.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.error != null && !state.joining) ...[
                        Text(
                          state.error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: state.loading || state.joining
                              ? null
                              : _load,
                          child: const Text('Tekrar dene'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!state.loading &&
                          state.error == null &&
                          state.rooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 200),
                          child: Column(
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 56,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Henüz açık oda yok',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      for (final room in state.rooms) ...[
                        RoomDirectoryTile(
                          room: room,
                          busy:
                              state.submitting &&
                              !room.isPrivate &&
                              state.joiningId == room.id,
                          enabled: !state.joining,
                          onJoin: () => _join(room),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
