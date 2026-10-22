import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/game_progress.dart';

class WordLetterCell extends StatelessWidget {
  const WordLetterCell({
    required this.character,
    required this.revealed,
    required this.focused,
    required this.index,
    required this.width,
    this.outcome,
    super.key,
  });

  final String? character;
  final bool revealed;
  final bool focused;
  final int index;
  final double width;
  final AnswerOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final correct = outcome == AnswerOutcome.correct;
    final beaten = outcome == AnswerOutcome.beaten;
    final color = correct
        ? AppColors.ready
        : beaten
        ? AppColors.warning
        : AppColors.danger;
    final base = revealed ? AppColors.cyan : AppColors.paper;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: outcome == null ? 0 : 1),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 850),
      builder: (context, value, _) {
        final progress = ((value - index * 0.035) / (1 - index * 0.035)).clamp(0.0, 1.0);
        final motion = math.sin(progress * math.pi * (correct || beaten ? 1 : 4)) * (1 - progress);
        return Transform.translate(
          offset: Offset(correct || beaten ? 0 : motion * 7, correct || beaten ? -motion * 6 : 0),
          child: Container(
            width: width,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: outcome == null ? base : Color.lerp(base, color, progress),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: focused && outcome == null ? AppColors.cyan : Colors.transparent, width: 2),
              boxShadow: outcome == null
                  ? null
                  : [BoxShadow(color: color.withValues(alpha: 0.25 * (1 - progress)), blurRadius: 12)],
            ),
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: FittedBox(
                key: ValueKey(character),
                fit: BoxFit.scaleDown,
                child: Text(
                  character ?? (focused ? '│' : ''),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: outcome != null ? AppColors.textPrimary : AppColors.onPaper,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
