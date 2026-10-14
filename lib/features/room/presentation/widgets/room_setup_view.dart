import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../domain/entities/room_game_mode.dart';
import '../cubit/room_setup_cubit.dart';
import '../cubit/room_setup_state.dart';
import '../widgets/room_game_summary.dart';
import '../widgets/room_join_info.dart';

class RoomSetupView extends StatelessWidget {
  const RoomSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomSetupCubit, RoomSetupState>(
      listenWhen: (previous, current) => previous.room != current.room,
      listener: (context, state) {
        final room = state.room;
        if (room == null) return;
        context.go('/room/${room.id}', extra: room);
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
                          RoomGameSummary(mode: state.gameMode),
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
                          const RoomJoinInfo(),
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
