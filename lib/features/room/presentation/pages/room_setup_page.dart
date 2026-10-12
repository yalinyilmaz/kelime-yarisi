import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/firebase_room_service.dart';
import '../../domain/entities/room_game_mode.dart';
import '../cubit/room_setup_cubit.dart';
import '../cubit/room_setup_state.dart';
import 'room_lobby_page.dart';

class RoomSetupPage extends StatelessWidget {
  const RoomSetupPage({required this.flow, super.key});

  final RoomSetupFlow flow;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          RoomSetupCubit(context.read<FirebaseRoomService>(), flow: flow),
      child: const _RoomSetupView(),
    );
  }
}

class _RoomSetupView extends StatelessWidget {
  const _RoomSetupView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomSetupCubit, RoomSetupState>(
      listenWhen: (previous, current) => previous.room != current.room,
      listener: (context, state) {
        final room = state.room;
        if (room == null) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => RoomLobbyPage(room: room)),
        );
      },
      builder: (context, state) {
        final isCreate = state.flow == RoomSetupFlow.create;
        return Scaffold(
          appBar: AppBar(title: Text(isCreate ? 'Oda Oluştur' : 'Odaya Katıl')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Text(
                isCreate
                    ? 'Arkadaşlarınla yarışacağın odayı hazırla.'
                    : 'Arkadaşının paylaştığı oda kodunu gir.',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                textCapitalization: TextCapitalization.words,
                onChanged: context.read<RoomSetupCubit>().displayNameChanged,
                decoration: const InputDecoration(
                  labelText: 'Oyuncu adın',
                  hintText: 'Örn. Erdem',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (isCreate) ...[
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: context.read<RoomSetupCubit>().roomNameChanged,
                  decoration: const InputDecoration(
                    labelText: 'Oda adı',
                    hintText: 'Örn. Cuma Akşamı',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Oyuncu sayısı'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [2, 3, 4, 5]
                      .map(
                        (count) => ChoiceChip(
                          label: Text('$count kişi'),
                          selected: state.targetPlayerCount == count,
                          onSelected: (_) => context
                              .read<RoomSetupCubit>()
                              .playerCountChanged(count),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Oyun modu'),
                const SizedBox(height: 12),
                SegmentedButton<RoomGameMode>(
                  segments: RoomGameMode.values
                      .map(
                        (mode) => ButtonSegment<RoomGameMode>(
                          value: mode,
                          label: Text(mode.label),
                          tooltip: mode.description,
                        ),
                      )
                      .toList(growable: false),
                  selected: {state.gameMode},
                  onSelectionChanged: (selection) => context
                      .read<RoomSetupCubit>()
                      .gameModeChanged(selection.first),
                ),
                const SizedBox(height: 10),
                Text(
                  state.gameMode.description,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ] else ...[
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onChanged: context.read<RoomSetupCubit>().roomCodeChanged,
                  decoration: const InputDecoration(
                    labelText: 'Oda kodu',
                    hintText: 'ABC-234',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: state.isSubmitting
                    ? null
                    : context.read<RoomSetupCubit>().submit,
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(isCreate ? 'Odayı Kur' : 'Odaya Gir'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
    );
  }
}
