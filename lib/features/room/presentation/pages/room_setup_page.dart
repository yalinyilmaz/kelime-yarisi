import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
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
        return NightStudioScaffold(
          appBar: AppBar(title: Text(isCreate ? 'Oda Oluştur' : 'Odaya Katıl')),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gutter = constraints.maxWidth <= 360 ? 20.0 : 24.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
                      children: [
                        Text(
                          isCreate
                              ? 'Arkadaşlarınla canlı yarışacağın odayı hazırla.'
                              : 'Arkadaşının paylaştığı oda koduyla stüdyoya gir.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.nickname],
                          textInputAction: isCreate
                              ? TextInputAction.next
                              : TextInputAction.next,
                          onChanged: context
                              .read<RoomSetupCubit>()
                              .displayNameChanged,
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
                            textInputAction: TextInputAction.done,
                            onChanged: context
                                .read<RoomSetupCubit>()
                                .roomNameChanged,
                            decoration: const InputDecoration(
                              labelText: 'Oda adı',
                              hintText: 'Örn. Cuma Akşamı',
                              prefixIcon: Icon(Icons.edit_outlined),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const StudioSectionLabel('Oyuncu sayısı'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 2, label: Text('2')),
                                ButtonSegment(value: 3, label: Text('3')),
                                ButtonSegment(value: 4, label: Text('4')),
                                ButtonSegment(value: 5, label: Text('5')),
                                ButtonSegment(value: 6, label: Text('6')),
                              ],
                              selected: {state.targetPlayerCount},
                              showSelectedIcon: false,
                              style: _segmentStyle(),
                              onSelectionChanged: (selection) => context
                                  .read<RoomSetupCubit>()
                                  .playerCountChanged(selection.first),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const StudioSectionLabel('Oyun modu'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<RoomGameMode>(
                              segments: RoomGameMode.values
                                  .map(
                                    (mode) => ButtonSegment<RoomGameMode>(
                                      value: mode,
                                      icon: Icon(
                                        mode == RoomGameMode.quick
                                            ? Icons.bolt_rounded
                                            : Icons.bar_chart_rounded,
                                      ),
                                      label: Text(mode.label),
                                      tooltip: mode.description,
                                    ),
                                  )
                                  .toList(growable: false),
                              selected: {state.gameMode},
                              showSelectedIcon: false,
                              style: _segmentStyle(),
                              onSelectionChanged: (selection) => context
                                  .read<RoomSetupCubit>()
                                  .gameModeChanged(selection.first),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _GameSummary(mode: state.gameMode),
                        ] else ...[
                          TextField(
                            textCapitalization: TextCapitalization.characters,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[A-Za-z0-9-]'),
                              ),
                              LengthLimitingTextInputFormatter(7),
                            ],
                            onChanged: context
                                .read<RoomSetupCubit>()
                                .roomCodeChanged,
                            onSubmitted: (_) {
                              if (state.canSubmit && !state.isSubmitting) {
                                context.read<RoomSetupCubit>().submit();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Oda kodu',
                              hintText: 'ABC-234',
                              prefixIcon: Icon(Icons.key_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _JoinInfo(),
                        ],
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: !state.canSubmit || state.isSubmitting
                              ? null
                              : context.read<RoomSetupCubit>().submit,
                          icon: state.isSubmitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(
                                  isCreate
                                      ? Icons.group_add_rounded
                                      : Icons.login_rounded,
                                ),
                          label: Text(isCreate ? 'Odayı Kur' : 'Odaya Gir'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _segmentStyle() {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.onPrimary
            : AppColors.textSecondary,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.surfaceElevated,
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: AppColors.outline)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _GameSummary extends StatelessWidget {
  const _GameSummary({required this.mode});

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

class _JoinInfo extends StatelessWidget {
  const _JoinInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.cyan),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aynı oda kodunu kullanan herkes, kendi cihazından aynı oyuna katılır.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
