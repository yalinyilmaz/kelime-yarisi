import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/studio_components.dart';
import '../../../room/domain/entities/game_room.dart';
import '../cubit/game_audio_cubit.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_board.dart';
import 'game_confirmation_dialogs.dart';
import 'game_sound_button.dart';

class GameView extends StatefulWidget {
  const GameView({super.key});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with WidgetsBindingObserver {
  final _answer = TextEditingController();
  bool _confirmingLeave = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<GameCubit>().setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    context.read<GameAudioCubit>().setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<GameCubit>().setForeground(state == AppLifecycleState.resumed);
    context.read<GameAudioCubit>().setForeground(
      state == AppLifecycleState.resumed,
    );
  }

  Future<void> _submit() =>
      context.read<GameCubit>().submitAnswer(_answer.text);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _answer.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final cubit = context.read<GameCubit>();
    if (_confirmingLeave || cubit.isClosed || cubit.state.isLeaving) return;
    _confirmingLeave = true;
    try {
      final confirmed = await GameConfirmationDialogs.leave(
        context,
        isHost: cubit.state.isHost,
        onLeave: () async {
          await cubit.leaveRoom();
          return !cubit.isClosed && cubit.state.isLeaving
              ? null
              : cubit.state.errorMessage ?? 'Odadan çıkılamadı. Tekrar dene.';
        },
      );
      if (confirmed && mounted) context.go('/multiplayer/rooms');
    } finally {
      _confirmingLeave = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<GameCubit, GameState, (bool, String, bool)>(
        selector: (state) => (
          state.isLeaving,
          state.room.name,
          state.room.status == RoomStatus.results,
        ),
        builder: (context, _) {
          final state = context.read<GameCubit>().state;
          final isResults = state.room.status == RoomStatus.results;
          return PopScope(
            canPop: state.isLeaving,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _leave();
            },
            child: NightStudioScaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  tooltip: 'Odadan çık',
                  onPressed: state.isLeaving ? null : _leave,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(isResults ? 'Yarışma tamamlandı' : state.room.name),
                actions: const [GameSoundButton()],
              ),
              body: GameBoard(answerController: _answer, onSubmit: _submit),
            ),
          );
        },
      );
}
