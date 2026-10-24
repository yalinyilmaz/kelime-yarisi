import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/speech/speech_input_cubit.dart';
import '../../../../core/widgets/studio_components.dart';
import '../cubit/solo_game_cubit.dart';
import '../cubit/solo_game_state.dart';
import 'solo_game_board.dart';
import 'solo_game_dialogs.dart';

class SoloGameView extends StatefulWidget {
  const SoloGameView({super.key});

  @override
  State<SoloGameView> createState() => _SoloGameViewState();
}

class _SoloGameViewState extends State<SoloGameView>
    with WidgetsBindingObserver {
  final _answer = TextEditingController();
  final _keyboardMode = ValueNotifier(false);
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<SoloGameCubit>().setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => context
      .read<SoloGameCubit>()
      .setForeground(state == AppLifecycleState.resumed);

  void _submit() => context.read<SoloGameCubit>().submitAnswer(_answer.text);

  void _setKeyboardMode(bool enabled) {
    if (_keyboardMode.value == enabled) return;
    if (enabled &&
        (!context.read<SoloGameCubit>().state.canAct ||
            context.read<SpeechInputCubit>().state.busy)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _answer.clear();
    _keyboardMode.value = enabled;
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final cubit = context.read<SoloGameCubit>();
      final ended =
          cubit.state.progress.finished ||
          cubit.state.phase == SoloGamePhase.expired;
      if (ended && !cubit.state.completionSaved) {
        await cubit.saveCompletion();
        if (!mounted) return;
      }
      if ((cubit.state.phase == SoloGamePhase.playing &&
              !cubit.state.progress.finished) ||
          (ended && !cubit.state.completionSaved)) {
        final confirmed = await SoloGameDialogs.leave(context);
        if (!mounted || !confirmed) return;
      }
      cubit.leave();
      if (mounted) context.go('/solo');
    } finally {
      _leaving = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardMode.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<SoloGameCubit, SoloGameState, (bool, bool)>(
        selector: (state) => (state.isLeaving, state.soundEnabled),
        builder: (context, values) => PopScope(
          canPop: values.$1,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: NightStudioScaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: 'Oyundan çık',
                onPressed: _leave,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('Tek Oyunculu'),
              actions: [
                IconButton(
                  tooltip: values.$2 ? 'Sesi kapat' : 'Sesi aç',
                  onPressed: context.read<SoloGameCubit>().toggleSound,
                  icon: Icon(
                    values.$2
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                ),
              ],
            ),
            body: ValueListenableBuilder(
              valueListenable: _keyboardMode,
              builder: (context, keyboardMode, _) => SoloGameBoard(
                answerController: _answer,
                onSubmit: _submit,
                onLeave: _leave,
                keyboardMode: keyboardMode,
                onKeyboardModeChanged: _setKeyboardMode,
              ),
            ),
          ),
        ),
      );
}
