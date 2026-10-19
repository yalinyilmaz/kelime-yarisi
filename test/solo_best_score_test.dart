import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelime_yarisi/features/solo/presentation/cubit/solo_best_score_cubit.dart';

import 'solo_game_test.dart' show MemoryScoreStorage;

void main() {
  test(
    'best score is restored and never replaced by a lower completed score',
    () async {
      final storage = MemoryScoreStorage();
      final first = SoloBestScoreCubit(storage: storage);
      first.recordCompletedScore(-400);
      expect(first.state, -400);
      first.recordCompletedScore(7200);
      first.recordCompletedScore(5000);
      await first.close();
      final restored = SoloBestScoreCubit(storage: storage);
      expect(restored.state, 7200);
      expect(() => restored.recordCompletedScore(9801), throwsArgumentError);
      await restored.close();
    },
  );

  test('real hydrated storage persists across closing and reopening the on-disk store', () async {
    final directory = await Directory.systemTemp.createTemp('ky_solo_score_');
    final location = HydratedStorageDirectory(directory.path);
    try {
      final storage = await HydratedStorage.build(storageDirectory: location);
      final score = SoloBestScoreCubit(storage: storage);
      score.recordCompletedScore(9800);
      await score.close();
      await storage.close();
      final reopened = await HydratedStorage.build(storageDirectory: location);
      final restored = SoloBestScoreCubit(storage: reopened);
      expect(restored.state, 9800);
      await restored.close();
      await reopened.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
