import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/game_answer_feedback.dart';
import '../../domain/game_progress.dart';

class AnswerFeedbackBanner extends StatelessWidget {
  const AnswerFeedbackBanner({
    required this.result,
    this.previousQuestion = false,
    super.key,
  });

  final GameAnswerFeedback result;
  final bool previousQuestion;

  @override
  Widget build(BuildContext context) {
    final beaten = result.outcome == AnswerOutcome.beaten;
    final color = result.isCorrect
        ? AppColors.ready
        : beaten
        ? AppColors.warning
        : AppColors.danger;
    return Semantics(
      liveRegion: true,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(result),
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 400),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                result.isCorrect
                    ? Icons.check_circle_rounded
                    : beaten
                    ? Icons.emoji_events_rounded
                    : Icons.cancel_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${previousQuestion ? 'Önceki soru · ' : ''}${result.label}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!result.isCorrect) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Doğru cevap: ${result.question.answer}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                result.scoreDelta == 0
                    ? '0'
                    : '${result.scoreDelta > 0 ? '+' : '−'}${result.scoreDelta.abs()}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
