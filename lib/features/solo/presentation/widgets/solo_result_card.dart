import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../game/presentation/widgets/answer_feedback_banner.dart';
import '../cubit/solo_best_score_cubit.dart';
import '../cubit/solo_game_cubit.dart';
import '../cubit/solo_game_state.dart';

class SoloResultCard extends StatelessWidget {
  const SoloResultCard({required this.state, required this.onLeave, super.key});
  final SoloGameState state;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final complete = state.progress.finished;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              complete ? Icons.emoji_events_rounded : Icons.timer_off_rounded,
              color: complete ? AppColors.warning : AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              complete ? 'Oyunu tamamladın' : 'Süre doldu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${state.progress.score} / 9.800',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(color: AppColors.cyan),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.progress.correctCount} doğru · ${state.progress.wrongCount} yanlış',
            ),
            const SizedBox(height: 16),
            if (!complete) ...[
              const Text(
                'Süre dolana kadar kazandığın puan kişisel rekorun için değerlendirilir. Set tamamlanmadığı için yeniden karşına çıkabilir.',
                textAlign: TextAlign.center,
              ),
              if (state.feedback != null) ...[
                const SizedBox(height: 16),
                AnswerFeedbackBanner(result: state.feedback!),
              ],
            ],
            if (state.isSavingCompletion)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else if (state.completionSaved)
              BlocSelector<SoloBestScoreCubit, int?, int?>(
                selector: (score) => score,
                builder: (_, score) => Text(
                  'Kişisel rekorun: ${score ?? 0}',
                  textAlign: TextAlign.center,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: context.read<SoloGameCubit>().saveCompletion,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Kaydı tekrar dene'),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state.isSavingCompletion ? null : onLeave,
              child: const Text('Tek Oyunculuya Dön'),
            ),
          ],
        ),
      ),
    );
  }
}
