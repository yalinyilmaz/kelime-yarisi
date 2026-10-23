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
  bool _preparingSpeech = false;
  bool _editingName = false;

  Future<void> _openMode(String route) async {
    if (_preparingSpeech) return;
    setState(() => _preparingSpeech = true);
    try {
      if (await prepareSpeechInput(context) && mounted) context.go(route);
    } finally {
      if (mounted) setState(() => _preparingSpeech = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PlayerNameCubit, String?>(
    builder: (context, name) {
      final needsName = name == null || _editingName;
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
                        minHeight: (constraints.maxHeight - (gutter * 2)).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(),
                            Text(
                              'CANLI KELİME YARIŞI',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                                  if (widget.invitationCode case final code?) {
                                    context.go(
                                      RoomInvitation.joinLocation(code),
                                    );
                                  } else {
                                    setState(() => _editingName = false);
                                  }
                                },
                                onCancel: name == null
                                    ? null
                                    : () =>
                                          setState(() => _editingName = false),
                              )
                            else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Merhaba, $name',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Oyuncu adını değiştir',
                                    onPressed: () => setState(() => _editingName = true),
                                    icon: const Icon(Icons.edit_outlined, size: 24),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _preparingSpeech
                                    ? null
                                    : () => _openMode('/solo'),
                                icon: const Icon(Icons.person_rounded),
                                label: const Text('Tek Oyunculu'),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _preparingSpeech
                                    ? null
                                    : () => _openMode('/multiplayer'),
                                icon: const Icon(Icons.group_rounded),
                                label: const Text('Çok Oyunculu'),
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
  );
}
