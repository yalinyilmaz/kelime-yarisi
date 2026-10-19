import 'package:hydrated_bloc/hydrated_bloc.dart';

class SoloBestScoreCubit extends HydratedCubit<int?> {
  SoloBestScoreCubit({super.storage}) : super(null);

  static const maximumScore = 9800;

  void recordCompletedScore(int score) {
    if (score < -maximumScore || score > maximumScore) {
      throw ArgumentError.value(score, 'score');
    }
    if (!isClosed && (state == null || score > state!)) emit(score);
  }

  @override
  String get storagePrefix => 'solo_best_score_v1';

  @override
  int? fromJson(Map<String, dynamic> json) {
    final score = json['bestScore'];
    return score is int && score >= -maximumScore && score <= maximumScore
        ? score
        : null;
  }

  @override
  Map<String, dynamic> toJson(int? state) => {'bestScore': state};
}
