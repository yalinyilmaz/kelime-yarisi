import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_mapper.dart';
import 'package:kelime_yarisi/features/game/domain/shared_hints.dart';

void main() {
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
