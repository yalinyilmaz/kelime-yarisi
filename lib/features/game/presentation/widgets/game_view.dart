import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/studio_components.dart';
import '../../../room/domain/entities/game_room.dart';
import '../../domain/game_progress.dart';
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
    final confirmed = await GameConfirmationDialogs.leave(
      context,
      isHost: cubit.state.isHost,
    );
    if (confirmed != true || !mounted) return;
    await cubit.leaveRoom();
    if (mounted && cubit.state.isLeaving) context.go('/');
  }

  Future<void> _giveUp() async {
    final cubit = context.read<GameCubit>();
    final index = cubit.state.questionIndex;
    final confirmed = await GameConfirmationDialogs.giveUp(
      context,
      points: cubit.state.questionValue,
    );
    if (confirmed == true && mounted) {
      await cubit.giveUp(questionIndex: index);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<GameCubit, GameState, _ViewSelection>(
        selector: (state) => (
          room: state.room,
          progress: state.progress,
          questionIndex: state.questionIndex,
          canAct: state.canAct,
          canEditAnswer: state.canEditAnswer,
          hasExpired: state.hasExpired,
          isConnected: state.isConnected,
          isLeaving: state.isLeaving,
          isSaving: state.isSaving,
          isVoting: state.isVoting,
          feedback: state.feedback,
          errorMessage: state.errorMessage,
          isHistoryReady: state.isHistoryReady,
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
              body: GameBoard(
                state: state,
                answerController: _answer,
                onSubmit: _submit,
                onGiveUp: _giveUp,
              ),
            ),
          );
        },
      );
}

typedef _ViewSelection = ({
  GameRoom room,
  GameProgress progress,
  int questionIndex,
  bool canAct,
  bool canEditAnswer,
  bool hasExpired,
  bool isConnected,
  bool isLeaving,
  bool isSaving,
  bool isVoting,
  String? feedback,
  String? errorMessage,
  bool isHistoryReady,
});
