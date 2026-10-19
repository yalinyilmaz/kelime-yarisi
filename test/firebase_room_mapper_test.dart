import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_mapper.dart';
import 'package:kelime_yarisi/features/game/domain/shared_hints.dart';

void main() {
  test('two clue texts and per-player dense or sparse usage survive Firebase mapping', () {
    final room = FirebaseRoomMapper.fromMap('abc234', {
      'questions': [
        {
          'clue': 'Bir giriş bölümü.',
          'answer': 'KAPI',
          'hints': ['Kilidi olabilir.', 'Koluna basıp geçersin.'],
        },
      ],
      'clueHintUsage': {
        'host': [2, null, 1],
        'guest': {'0': 1, '2': 2},
      },
    });
    expect(room.questions.single.hints, [
      'Kilidi olabilir.',
      'Koluna basıp geçersin.',
    ]);
    expect(room.clueHintUsage['host'], {0: 2, 2: 1});
    expect(room.clueHintUsage['guest'], {0: 1, 2: 2});
    expect(
      room.copyWith(status: room.status).clueHintUsage,
      room.clueHintUsage,
    );
  });
  test('legacy room payloads remain compatible with live rules before pool deployment', () {
    final legacy = FirebaseRoomMapper.fromMap('abc234', {});
    expect(
      FirebaseRoomMapper.toMap(legacy).containsKey('questionEngine'),
      isFalse,
    );
    final pooled = FirebaseRoomMapper.fromMap('abc234', {
      'questionEngine': 'pool-v1',
    });
    expect(FirebaseRoomMapper.toMap(pooled)['questionEngine'], 'pool-v1');
  });
  test(
    'Dense Firebase lists and sparse maps preserve the same shared hints',
    () {
      final first = const SharedHints(revealedCount: 1).toMap(0);
      final third = const SharedHints(
        revealedCount: 2,
        firstVoterId: 'host',
      ).toMap(2);
      final arrayRoom = FirebaseRoomMapper.fromMap('abc234', {
        'hints': [first, null, third],
      });
      final mapRoom = FirebaseRoomMapper.fromMap('abc234', {
        'hints': {'0': first, '2': third},
      });
      expect(arrayRoom.hints, mapRoom.hints);
      expect(arrayRoom.hints[0]!.revealedCount, 1);
      expect(arrayRoom.hints.containsKey(1), isFalse);
      expect(arrayRoom.hints[2]!.firstVoterId, 'host');
    },
  );
}
