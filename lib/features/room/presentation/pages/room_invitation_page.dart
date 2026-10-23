import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/profile/player_name_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../data/firebase_room_service.dart';
import '../cubit/room_setup_cubit.dart';
import '../cubit/room_setup_state.dart';

class RoomInvitationPage extends StatelessWidget {
  const RoomInvitationPage({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RoomSetupCubit(
      context.read<FirebaseRoomService>(),
      flow: RoomSetupFlow.join,
      displayName: context.read<PlayerNameCubit>().state!,
      initialRoomCode: code,
    )..submit(),
    child: const _InvitationView(),
  );
}

class _InvitationView extends StatelessWidget {
  const _InvitationView();

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RoomSetupCubit, RoomSetupState>(
    listenWhen: (previous, current) => previous.room != current.room,
    listener: (context, state) {
      if (state.room case final room?) {
        context.go('/room/${room.id}', extra: room);
      }
    },
    builder: (context, state) {
      final failed = state.errorMessage != null;
      final (title, message) = switch (state.errorCode) {
        'room-not-found' || 'room-closed' => (
          'Oda artık aktif değil',
          'Bu davetin odası kapatılmış veya artık mevcut değil. Arkadaşından yeni bir davet isteyebilirsin.',
        ),
        // RTDB denies all three cases with the same permission error.
        // Do not claim that the room is full when its actual status is unknown.
        'join-rejected' => (
          'Oda müsait değil',
          'Oda dolu, kapatılmış ya da oyun başlamış olabilir. Bir yer açıldığında aynı davetle tekrar deneyebilirsin.',
        ),
        _ => ('Odaya katılamadın', state.errorMessage ?? ''),
      };
      return NightStudioScaffold(
        appBar: AppBar(title: const Text('Oda Daveti')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (failed)
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 56,
                          color: AppColors.cyan,
                        )
                      else
                        const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 24),
                      Text(
                        failed ? title : 'Odaya katılıyorsun',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        failed ? message : 'Davetin kontrol ediliyor. Birazdan arkadaşlarının yanında olacaksın.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Oda kodu: ${state.roomCode}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      if (failed) ...[
                        FilledButton.icon(
                          onPressed: context.read<RoomSetupCubit>().submit,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tekrar Dene'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ana Menüye Dön'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
