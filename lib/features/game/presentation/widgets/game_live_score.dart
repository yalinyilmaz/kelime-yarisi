import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_score_card.dart';

class GameLiveScore extends StatelessWidget {
  const GameLiveScore({super.key});
  @override
  Widget build(BuildContext context) => BlocSelector<GameCubit, GameState, int>(
    selector: (s) => s.progress.score,
    builder: (context, score) => GameScoreCard(score: score),
  );
}
