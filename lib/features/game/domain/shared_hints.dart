import 'package:equatable/equatable.dart';

class SharedHints extends Equatable {
  const SharedHints({this.revealedCount = 0, this.firstVoterId});

  final int revealedCount;
  final String? firstVoterId;

  SharedHints? vote(
    String uid, {
    required int requiredVotes,
    required int letterCount,
  }) {
    if (revealedCount >= letterCount - 1 || firstVoterId == uid) return null;
    if (requiredVotes == 1 || firstVoterId != null) {
      return SharedHints(revealedCount: revealedCount + 1);
    }
    return SharedHints(revealedCount: revealedCount, firstVoterId: uid);
  }

  // Stable across devices/platforms; no client can choose a different shared letter.
  int revealedMask(String roomId, int questionIndex, int letterCount) {
    var seed = roomId.codeUnits.fold(
      17,
      (value, code) => (value * 31 + code) % 2147483647,
    );
    seed = (seed + questionIndex + 1) % 2147483647;
    final positions = List.generate(letterCount, (index) => index);
    for (var i = positions.length - 1; i > 0; i--) {
      seed = (seed * 48271) % 2147483647;
      final swap = seed % (i + 1);
      final old = positions[i];
      positions[i] = positions[swap];
      positions[swap] = old;
    }
    return positions
        .take(revealedCount.clamp(0, letterCount - 1))
        .fold(0, (mask, index) => mask | (1 << index));
  }

  Map<String, Object?> toMap(int questionIndex) => {
    'questionIndex': questionIndex,
    'revealedCount': revealedCount,
    if (firstVoterId != null) 'firstVoterId': firstVoterId,
  };

  static SharedHints fromMap(Object? value) {
    final map = value is Map ? value : const {};
    return SharedHints(
      revealedCount: (map['revealedCount'] as num?)?.toInt() ?? 0,
      firstVoterId: map['firstVoterId'] as String?,
    );
  }

  @override
  List<Object?> get props => [revealedCount, firstVoterId];
}
