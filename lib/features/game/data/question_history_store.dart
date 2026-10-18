import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Device-local completed set IDs only. Partial games never enter this history.
class QuestionHistoryStore {
  QuestionHistoryStore({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? databasePath;
  Future<Database>? _opening;

  Future<Database> get _database =>
      _opening ??= _open().catchError((Object error, StackTrace stack) {
        _opening = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<Database> _open() async {
    final resolvedPath =
        databasePath ??
        path.join(
          await _factory.getDatabasesPath(),
          'question_history',
          'history.sqlite',
        );
    if (databasePath == null) {
      final directory = path.dirname(resolvedPath);
      await Directory(directory).create(recursive: true);
      if (Platform.isIOS) {
        await const MethodChannel('kelime_yarisi/question_history')
            .invokeMethod<void>('excludeFromBackup', {'path': directory});
      }
    }
    return _factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) => _createCompletedSets(db),
        // Old per-question rows cannot prove that a game was completed.
        // Keep them intact, but exclude only the new completion records.
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createCompletedSets(db);
        },
      ),
    );
  }

  static Future<void> _createCompletedSets(Database db) => db.execute(
    'CREATE TABLE completed_sets '
    '(id TEXT PRIMARY KEY, completed_at_ms INTEGER NOT NULL) WITHOUT ROWID',
  );

  Future<Map<String, List<String>>> snapshot() async {
    final db = await _database;
    return {
      'seenAnswerIds': const [],
      'seenQuestionIds': const [],
      'completedSetIds': [
        for (final row in await db.query('completed_sets', columns: ['id']))
          row['id']! as String,
      ],
    };
  }

  Future<void> recordCompleted(String setId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(setId)) {
      throw StateError('Set kimliği geçersiz.');
    }
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('completed_sets', {
      'id': setId,
      'completed_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
