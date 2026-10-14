import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/game_state.dart';

class GameScoreboard extends StatelessWidget {
  const GameScoreboard({super.key, required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final standing in state.standings)
          Card(
            child: ListTile(
              leading: Text('${standing.rank}'),
              title: Text(
                '${standing.player.displayName}${standing.player.id == state.currentUserId ? ' (Sen)' : ''}',
              ),
              subtitle: Text(
                !standing.player.isOnline
                    ? 'Çevrimdışı'
                    : standing.progress.finished
                    ? 'Tamamlandı'
                    : state.hasExpired
                    ? 'Sonuç bekleniyor'
                    : '${standing.progress.questionIndex} soru tamamlandı',
              ),
              trailing: Text(
                '${standing.progress.score}',
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
