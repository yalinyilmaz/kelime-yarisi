import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/data/question_bank.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

void main() {
  test('Both modes have a stable set and increasing word lengths', () {
    for (final mode in RoomGameMode.values) {
      final questions = QuestionBank.forSet(QuestionBank.setIdFor(mode));
      expect(questions.length, mode.questionCount);
      expect(questions.map((q) => q.answer).toSet().length, questions.length);
      final lengths = questions.map((q) => q.letterCount).toList();
      expect(lengths, [...lengths]..sort());
      expect(lengths.first, 4);
      expect(lengths.last, 10);
      expect(
        questions.every(
          (q) => q.answer == GameQuestion.normalizeAnswer(q.answer),
        ),
        isTrue,
      );
    }
    expect(() => QuestionBank.forSet('quick-v2'), throwsStateError);
  });

  test('Answer matching respects Turkish dotted and dotless I', () {
    const book = GameQuestion(clue: '', answer: 'KİTAP');
    const door = GameQuestion(clue: '', answer: 'KAPI');
    expect(book.accepts('  kitap  '), isTrue);
    expect(book.accepts('KİTAP'), isTrue);
    expect(book.accepts('kıtap'), isFalse);
    expect(door.accepts('kapı'), isTrue);
    expect(door.accepts('kapi'), isFalse);
    expect(book.accepts('ki\ntap'), isTrue);
  });

  test('Hints never repeat, affect only one player, and keep the last letter hidden', () {
    final question = QuestionBank.forSet('quick-v1').first;
    const otherPlayer = GameProgress();
    var progress = const GameProgress();
    final random = Random(5);
    for (var i = 0; i < question.letterCount - 1; i++) {
      final previousMask = progress.revealedMask;
      progress = progress.revealLetter(question, random);
      expect(progress.revealedMask & previousMask, previousMask);
      expect(progress.valueFor(question), (question.letterCount - i - 1) * 100);
      expect(progress.score, 0);
    }
    expect(progress.revealLetter(question, random), progress);
    expect(otherPlayer.revealedMask, 0);
    expect(progress.resolve([question], correct: true).score, 100);
    expect(progress.resolve([question], correct: false).score, -100);
  });

  test('Every answer advances once, resets hints, and final question freezes progress', () {
    final questions = QuestionBank.forSet('quick-v1');
    var progress = const GameProgress().revealLetter(
      questions.first,
      Random(2),
    );
    progress = progress.resolve(questions, correct: false);
    expect(progress.score, -300);
    expect(progress.questionIndex, 1);
    expect(progress.revealedMask, 0);
    for (var i = 1; i < questions.length; i++) {
      progress = progress.resolve(questions, correct: true);
    }
    expect(progress.finished, isTrue);
    expect(progress.correctCount, 6);
    expect(progress.wrongCount, 1);
    expect(progress.score, 4200);
    expect(progress.resolve(questions, correct: true), progress);
  });

  test('Timeout penalizes the open question once and leaves later questions unattempted', () {
    final questions = QuestionBank.forSet('classic-v1');
    final progress = const GameProgress()
        .resolve(questions, correct: true)
        .revealLetter(questions[1], Random(1));
    final expired = progress.resolve(questions, correct: false, timedOut: true);
    expect(expired.score, 100);
    expect(expired.questionIndex, 2);
    expect(expired.finished, isTrue);
    expect(expired.wrongCount, 1);
    expect(expired.resolve(questions, correct: false, timedOut: true), expired);
  });
}
