import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_stat_card.dart';

class QuestionClock extends StatelessWidget {
  const QuestionClock({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<GameCubit, GameState, (bool, int)>(
    selector: (state) => (state.clockReady, state.remainingSeconds),
    builder: (context, clock) => GameStatCard(
      label: 'SORU SÜRESİ',
      value: clock.$1
          ? '${clock.$2 ~/ 60}:${(clock.$2 % 60).toString().padLeft(2, '0')}'
          : '—',
      color: clock.$2 <= 5 ? AppColors.warning : AppColors.textPrimary,
    ),
  );
}
