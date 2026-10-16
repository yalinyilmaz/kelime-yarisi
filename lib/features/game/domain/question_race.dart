import 'package:equatable/equatable.dart';

class QuestionRace extends Equatable {
  const QuestionRace({
    required this.questionIndex,
    required this.startedAtMs,
    this.nextAtMs,
    this.winnerId,
    this.winnerName,
  });

  final int questionIndex;
  final int startedAtMs;
  final int? nextAtMs;
  final String? winnerId;
  final String? winnerName;
  bool get isResolved => nextAtMs != null;

  factory QuestionRace.fromMap(Map<Object?, Object?> map) => QuestionRace(
    questionIndex: (map['questionIndex'] as num).toInt(),
    startedAtMs: (map['startedAtMs'] as num).toInt(),
    nextAtMs: (map['nextAtMs'] as num?)?.toInt(),
    winnerId: map['winnerId'] as String?,
    winnerName: map['winnerName'] as String?,
  );

  @override
  List<Object?> get props => [
    questionIndex,
    startedAtMs,
    nextAtMs,
    winnerId,
    winnerName,
  ];
}
