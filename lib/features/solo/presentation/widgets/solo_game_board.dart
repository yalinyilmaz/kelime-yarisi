import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../game/presentation/widgets/game_notice.dart';
import '../../../game/presentation/widgets/game_stat_card.dart';
import '../cubit/solo_game_cubit.dart';
import '../cubit/solo_game_state.dart';
import 'solo_game_actions.dart';
import 'solo_question_card.dart';
import 'solo_result_card.dart';

class SoloGameBoard extends StatelessWidget {
  const SoloGameBoard({
    required this.answerController,
    required this.onSubmit,
    required this.onGiveUp,
    required this.onLeave,
    super.key,
  });
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  final VoidCallback onGiveUp;
  final VoidCallback onLeave;

  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<SoloGameCubit, SoloGameState, SoloGameState>(
    selector: (state) => state,
    builder: (context, state) {
      if (state.phase == SoloGamePhase.idle ||
          state.phase == SoloGamePhase.loading) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Soru setin hazırlanıyor…'),
            ],
          ),
        );
      }
      if (state.phase == SoloGamePhase.failed) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: context.read<SoloGameCubit>().start,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        );
      }
      final playing = state.phase == SoloGamePhase.playing;
      return SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GameStatCard(
                              label: 'PUANIN',
                              value: '${state.progress.score}',
                              color: AppColors.cyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GameStatCard(
                              label: 'KALAN SÜRE',
                              value:
                                  '${state.remainingSeconds ~/ 60}:${(state.remainingSeconds % 60).toString().padLeft(2, '0')}',
                              color: state.remainingSeconds <= 20
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (state.errorMessage != null)
                        GameNotice(state.errorMessage!, error: true),
                      if (playing && state.question != null) ...[
                        SoloQuestionCard(
                          state: state,
                          answerController: answerController,
                          onSubmit: onSubmit,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Her harf soru değerini 100 puan azaltır. Yanlış cevapta soru değeri kadar puan kaybedersin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ] else
                        SoloResultCard(state: state, onLeave: onLeave),
                    ],
                  ),
                ),
                if (playing && state.question != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SoloGameActions(state: state, onSubmit: onSubmit),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
