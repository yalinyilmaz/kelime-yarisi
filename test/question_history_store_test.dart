import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/data/question_history_store.dart';
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
    expect((await store.snapshot())['completedSetIds'], isEmpty);
    await store.close();
  });

  test('only completed set IDs persist across reopen; clearing app data resets history', () async {
    final directory = await Directory.systemTemp.createTemp('set-history-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = '${directory.path}/history.sqlite';
    var store = QuestionHistoryStore(
      factory: databaseFactoryFfi,
      databasePath: file,
    );
    expect((await store.snapshot())['completedSetIds'], isEmpty);
    await Future.wait([
      store.recordCompleted('initial_001'),
      store.recordCompleted('initial_001'),
    ]);
    await store.close();
    store = QuestionHistoryStore(
      factory: databaseFactoryFfi,
      databasePath: file,
    );
    expect(await store.snapshot(), {
      'seenAnswerIds': [],
      'seenQuestionIds': [],
      'completedSetIds': ['initial_001'],
    });
    await expectLater(store.recordCompleted('../invalid'), throwsStateError);
    await store.close();
    await databaseFactoryFfi.deleteDatabase(file);
    store = QuestionHistoryStore(
      factory: databaseFactoryFfi,
      databasePath: file,
    );
    expect((await store.snapshot())['completedSetIds'], isEmpty);
    await store.close();
  });

  test('v1 shown-question rows are preserved but cannot count as completed sets', () async {
    final directory = await Directory.systemTemp.createTemp(
      'set-history-migration',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = '${directory.path}/history.sqlite';
    final old = await databaseFactoryFfi.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final name in ['seen_answers', 'seen_questions']) {
            await db.execute(
              'CREATE TABLE $name (id TEXT PRIMARY KEY, seen_at_ms INTEGER NOT NULL) WITHOUT ROWID',
            );
            await db.insert(name, {
              'id': 'partial_question',
              'seen_at_ms': 1000,
            });
          }
        },
      ),
    );
    await old.close();
    final store = QuestionHistoryStore(
      factory: databaseFactoryFfi,
      databasePath: file,
    );
    expect((await store.snapshot())['completedSetIds'], isEmpty);
    expect((await store.snapshot())['seenQuestionIds'], isEmpty);
    await store.recordCompleted('initial_002');
    await store.close();
    final check = await databaseFactoryFfi.openDatabase(file);
    expect(
      (await check.query('seen_questions')).single['id'],
      'partial_question',
    );
    expect((await check.query('completed_sets')).single['id'], 'initial_002');
    await check.close();
  });
}
