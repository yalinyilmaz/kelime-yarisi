import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/speech/voice_answer_button.dart';
import '../../../../core/config/room_invitation.dart';
import '../../../../core/profile/player_name_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../widgets/player_name_form.dart';

class RoomHomePage extends StatefulWidget {
  const RoomHomePage({this.invitationCode, super.key});

  final String? invitationCode;

  @override
  State<RoomHomePage> createState() => _RoomHomePageState();
}

class _RoomHomePageState extends State<RoomHomePage> {
  final _preparingSpeech = ValueNotifier(false);
  final _editingName = ValueNotifier(false);

  Future<void> _openMode(String route) async {
    if (_preparingSpeech.value) return;
    _preparingSpeech.value = true;
    try {
      if (await prepareSpeechInput(context) && mounted) context.go(route);
    } finally {
      if (mounted) _preparingSpeech.value = false;
    }
  }

  @override
  void dispose() {
    _preparingSpeech.dispose();
    _editingName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _editingName,
    builder: (context, editing, _) => BlocBuilder<PlayerNameCubit, String?>(
      builder: (context, name) {
        final needsName = name == null || _editingName.value;
        return NightStudioScaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gutter = constraints.maxWidth <= 360 ? 20.0 : 24.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(gutter),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - (gutter * 2))
                              .clamp(0, double.infinity),
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(),
                              Text(
                                'CANLI KELİME YARIŞI',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      letterSpacing: 3,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              const Center(child: StudioMark(width: 148)),
                              const SizedBox(height: 24),
                              Text(
                                'Kelime Yarışı',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displayLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Kelimelerinle fark yarat.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              if (needsName)
                                PlayerNameForm(
                                  onSaved: () {
                                    if (widget.invitationCode
                                        case final code?) {
                                      context.go(
                                        RoomInvitation.joinLocation(code),
                                      );
                                    } else {
                                      _editingName.value = false;
                                    }
                                  },
                                  onCancel: name == null
                                      ? null
                                      : () => _editingName.value = false,
                                )
                              else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Merhaba, $name',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Oyuncu adını değiştir',
                                      onPressed: () =>
                                          _editingName.value = true,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ValueListenableBuilder(
                                  valueListenable: _preparingSpeech,
                                  builder: (context, preparing, _) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: preparing
                                            ? null
                                            : () => _openMode('/solo'),
                                        icon: const Icon(Icons.person_rounded),
                                        label: const Text('Tek Oyunculu'),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: preparing
                                            ? null
                                            : () => _openMode('/multiplayer'),
                                        icon: const Icon(Icons.group_rounded),
                                        label: const Text('Çok Oyunculu'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      color: AppColors.cyan,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Kendi rekorunu kır veya arkadaşlarınla yarış.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
