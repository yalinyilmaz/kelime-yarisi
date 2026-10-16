import 'package:equatable/equatable.dart';

class QuestionCapacity extends Equatable {
  const QuestionCapacity({required this.groups, required this.upperBoundGames});
  factory QuestionCapacity.fromMap(Map map) => QuestionCapacity(
    groups: List.unmodifiable([
      for (final item in map['groups'] as List)
        QuestionCapacityGroup.fromMap(item as Map),
    ]),
    upperBoundGames: (map['upperBoundSets'] as num).toInt(),
  );
  final List<QuestionCapacityGroup> groups;
  final int upperBoundGames;
  @override
  List<Object?> get props => [groups, upperBoundGames];
}

class QuestionCapacityGroup extends Equatable {
  const QuestionCapacityGroup({
    required this.length,
    required this.total,
    required this.approved,
    required this.published,
    required this.remaining,
    required this.required,
  });
  factory QuestionCapacityGroup.fromMap(Map map) => QuestionCapacityGroup(
    length: (map['length'] as num).toInt(),
    total: (map['totalAnswers'] as num).toInt(),
    approved: (map['approvedAnswers'] as num).toInt(),
    published: (map['publishedAnswers'] as num).toInt(),
    remaining: (map['remainingAnswers'] as num).toInt(),
    required: (map['needed'] as num).toInt(),
  );
  final int length, total, approved, published, remaining, required;
  bool get blocked => remaining < required;
  @override
  List<Object?> get props => [
    length,
    total,
    approved,
    published,
    remaining,
    required,
  ];
}
