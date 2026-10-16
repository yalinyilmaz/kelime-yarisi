import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/game_question.dart';

/// Device-local IDs only. Clues and answer text are never written to this DB.
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
        version: 1,
        onCreate: (db, _) async {
          for (final table in ['seen_answers', 'seen_questions']) {
            await db.execute(
              'CREATE TABLE $table '
              '(id TEXT PRIMARY KEY, seen_at_ms INTEGER NOT NULL) WITHOUT ROWID',
            );
          }
        },
      ),
    );
  }

  Future<Map<String, List<String>>> snapshot() async {
    final db = await _database;
    return db.transaction(
      (transaction) async => {
        'seenAnswerIds': [
          for (final row in await transaction.query(
            'seen_answers',
            columns: ['id'],
          ))
            row['id']! as String,
        ],
        'seenQuestionIds': [
          for (final row in await transaction.query(
            'seen_questions',
            columns: ['id'],
          ))
            row['id']! as String,
        ],
      },
    );
  }

  Future<void> recordShown(GameQuestion question) async {
    if (question.id == null || question.answerId == null) {
      throw StateError('Soru kimliği eksik.');
    }
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((transaction) async {
      for (final item in [
        (table: 'seen_answers', id: question.answerId!),
        (table: 'seen_questions', id: question.id!),
      ]) {
        await transaction.insert(item.table, {
          'id': item.id,
          'seen_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
