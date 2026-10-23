import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import 'game_scoreboard.dart';

class GameStandings extends StatelessWidget {
  const GameStandings({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<GameCubit, GameState>(
    buildWhen: (a, b) =>
        !listEquals(a.room.players, b.room.players) ||
        !mapEquals(a.room.progress, b.room.progress) ||
        a.progress != b.progress ||
        a.hasExpired != b.hasExpired,
    builder: (context, state) => GameScoreboard(state: state),
  );
}
