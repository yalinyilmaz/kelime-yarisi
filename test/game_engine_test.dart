import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/data/question_bank.dart';
import 'package:kelime_yarisi/features/game/domain/game_progress.dart';
import 'package:kelime_yarisi/features/game/domain/game_question.dart';
import 'package:kelime_yarisi/features/game/domain/shared_hints.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

void main() {
  test(
    'Two-word answers count letters only and accept reviewed equivalents',
    () {
      const question = GameQuestion(
        clue: '',
        answer: 'NEFES ALMAK',
        acceptedAnswers: ['SOLUK ALMAK'],
      );
      expect(question.letterCount, 10);
      expect(question.wordLengths, [5, 5]);
      expect(question.accepts('soluk almak'), isTrue);
      expect(question.accepts('nefesalmak'), isTrue);
      expect(question.accepts('soluk vermek'), isFalse);
      expect(question.normalizeLetter('a', 5), 'A');
      expect(question.answer, 'NEFES ALMAK');
    },
  );

  test('Stable question sets and 25-second rounds in both modes', () {
    for (final mode in RoomGameMode.values) {
      final questions = QuestionBank.forSet(QuestionBank.setIdFor(mode));
      expect(questions.length, mode.questionCount);
      final lengths = questions.map((q) => q.letterCount).toList();
      expect(lengths, [...lengths]..sort());
      expect(mode.duration.inSeconds, mode.questionCount * 25);
    }
    expect(() => QuestionBank.forSet('unknown'), throwsStateError);
  });

  test('Turkish and ASCII letters match regardless of case', () {
    const examples = {
      'KAPI': ['kapı', 'kapi', 'KAPI', 'KAPİ'],
      'KİTAP': ['kitap', 'kıtap', 'KITAP', 'KİTAP'],
      'GÖKKUŞAĞI': [
        'gokkusagi',
        'GOKKUSAGI',
        'gÖkKuŞaĞı',
        'go\u0308kkus\u0327ag\u0306i',
      ],
      'ÇEKİRDEK': ['cekirdek', 'CEKIRDEK', 'ÇEKİRDEK'],
      'ŞÜPHE': ['suphe', 'SUPHE', 'şüphe'],
      'IŞIK': ['isik', 'ISIK', 'ışık', 'İSİK'],
    };
    for (final entry in examples.entries) {
      final question = GameQuestion(clue: '', answer: entry.key);
      for (final input in entry.value) {
        expect(
          question.accepts('  $input  '),
          isTrue,
          reason: '${entry.key}: $input',
        );
      }
    }
    const door = GameQuestion(clue: '', answer: 'KAPI');
    for (final input in ['', 'kap', 'kapilar', 'kedi', 'kap1', 'kap!']) {
      expect(door.accepts(input), isFalse, reason: input);
    }
  });

  test('PIN letter conversion preserves real spelling and does not correct wrong letters', () {
    const question = GameQuestion(clue: '', answer: 'GÖKKUŞAĞI');
    expect(
      [for (var i = 0; i < 9; i++) question.normalizeLetter('gokkusagi'[i], i)]
          .join(),
      'GÖKKUŞAĞI',
    );
    expect(question.normalizeLetter('e', 1), 'E');
    expect(question.accepts('gekkusagi'), isFalse);
  });

  test('One vote opens a shared letter for two and three player rooms', () {
    final next = const SharedHints().vote(
      'a',
      requiredVotes: 1,
      letterCount: 4,
    )!;
    expect(next.revealedCount, 1);
    expect(next.firstVoterId, isNull);
    expect(
      next.revealedMask('abc234', 0, 4),
      SharedHints.fromMap(next.toMap(0)).revealedMask('abc234', 0, 4),
    );
  });

  test('Two different votes open a letter, reset votes, and never reveal the last letter', () {
    var hints = const SharedHints();
    var oldMask = 0;
    for (var i = 0; i < 3; i++) {
      hints = hints.vote('a', requiredVotes: 2, letterCount: 4)!;
      expect(hints.revealedCount, i);
      expect(hints.vote('a', requiredVotes: 2, letterCount: 4), isNull);
      hints = hints.vote('b', requiredVotes: 2, letterCount: 4)!;
      expect(hints.revealedCount, i + 1);
      expect(hints.firstVoterId, isNull);
      final mask = hints.revealedMask('abc234', 0, 4);
      expect(mask & oldMask, oldMask);
      expect(
        [
          for (var j = 0; j < 4; j++)
            if ((mask & (1 << j)) != 0) j,
        ].length,
        i + 1,
      );
      oldMask = mask;
    }
    expect(hints.vote('a', requiredVotes: 2, letterCount: 4), isNull);
  });

  test('Shared hints determine points; timeout resolves a question without ending the game', () {
    final questions = QuestionBank.forSet('quick-v1');
    var progress = const GameProgress().resolve(
      questions,
      outcome: AnswerOutcome.correct,
      revealedCount: 1,
    );
    expect(progress.score, 300);
    progress = progress.resolve(
      questions,
      outcome: AnswerOutcome.timeout,
      revealedCount: 2,
    );
    expect(progress.score, 0);
    expect(progress.questionIndex, 2);
    expect(progress.finished, isFalse);
    for (var i = 2; i < questions.length; i++) {
      progress = progress.resolve(
        questions,
        outcome: AnswerOutcome.wrong,
        revealedCount: 0,
      );
    }
    expect(progress.finished, isTrue);
    expect(progress.correctCount, 1);
    expect(progress.wrongCount, 6);
    expect(
      progress.resolve(
        questions,
        outcome: AnswerOutcome.correct,
        revealedCount: 0,
      ),
      progress,
    );
  });
}
