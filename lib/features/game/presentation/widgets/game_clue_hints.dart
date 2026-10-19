import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';

class GameClueHintButton extends StatelessWidget {
  const GameClueHintButton({required this.state, super.key});

  final GameState state;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: TextButton.icon(
      key: const ValueKey('clue-hint-action'),
      onPressed: state.canRequestClueHint
          ? context.read<GameCubit>().requestClueHint
          : null,
      style: TextButton.styleFrom(
        foregroundColor: Colors.amber.shade300,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: state.isRequestingClueHint
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.amber,
              ),
            )
          : const Icon(Icons.lightbulb_rounded, size: 22),
      label: Tooltip(
        message: 'İpucu · Bu soruda ${state.currentClueHintCount}/2 kullanıldı',
        child: Text('${state.remainingClueHints}/10'),
      ),
    ),
  );
}

class GameClueHints extends StatelessWidget {
  const GameClueHints({required this.state, super.key});

  final GameState state;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 220),
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: state.visibleClueHints.isEmpty
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(
                '${state.questionIndex}-${state.currentClueHintCount}',
              ),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  for (var i = 0; i < state.visibleClueHints.length; i++)
                    Text(
                      '${i + 1}. ${state.visibleClueHints[i]}',
                      style: TextStyle(color: Colors.amber.shade100),
                    ),
                ],
              ),
            ),
    ),
  );
}
