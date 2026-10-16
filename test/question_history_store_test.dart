import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/data/question_history_store.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class RetryDatabaseFactory extends Fake implements DatabaseFactory {
  var attempts = 0;
  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) {
    if (attempts++ == 0) return Future.error(StateError('Temporary failure'));
    return databaseFactoryFfi.openDatabase(path, options: options);
  }
}

void main() {
  sqfliteFfiInit();
  test('a failed SQLite open can recover on the next attempt', () async {
    final store = QuestionHistoryStore(
      factory: RetryDatabaseFactory(),
      databasePath: inMemoryDatabasePath,
    );
    await expectLater(store.snapshot(), throwsStateError);
    expect((await store.snapshot())['seenAnswerIds'], isEmpty);
    await store.close();
  });
  test('SQLite persists only shown IDs across reopen; variants share answer history', () async {
    final factory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp(
      'question-history-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/history.sqlite';
    await factory.deleteDatabase(databasePath);
    var store = QuestionHistoryStore(
      factory: factory,
      databasePath: databasePath,
    );
    const first = GameQuestion(
      id: 'q1',
      answerId: 'w1',
      clue: 'Bir geçit.',
      answer: 'KAPI',
    );
    const variant = GameQuestion(
      id: 'q2',
      answerId: 'w1',
      clue: 'Bir giriş bölümü.',
      answer: 'KAPI',
    );
    expect((await store.snapshot())['seenAnswerIds'], isEmpty);
    await Future.wait([
      store.recordShown(first),
      store.recordShown(first),
      store.recordShown(variant),
    ]);
    await store.close();
    store = QuestionHistoryStore(factory: factory, databasePath: databasePath);
    expect((await store.snapshot())['seenAnswerIds'], ['w1']);
    expect((await store.snapshot())['seenQuestionIds']!.toSet(), {'q1', 'q2'});
    await store.close();
    // Simulates removal of app data. No server/account history is restored.
    await factory.deleteDatabase(databasePath);
    store = QuestionHistoryStore(factory: factory, databasePath: databasePath);
    expect((await store.snapshot())['seenAnswerIds'], isEmpty);
    await store.close();
    await factory.deleteDatabase(databasePath);
  });

  test(
    'an unallocated/legacy question cannot create an incomplete history row',
    () async {
      final store = QuestionHistoryStore(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      await expectLater(
        store.recordShown(const GameQuestion(clue: 'Deneme', answer: 'KAPI')),
        throwsStateError,
      );
      expect((await store.snapshot())['seenAnswerIds'], isEmpty);
      await store.close();
    },
  );
}
