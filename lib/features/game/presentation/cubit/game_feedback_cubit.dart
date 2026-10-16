import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/game_answer_feedback.dart';
import 'game_cubit.dart';
import 'game_state.dart';

/// Owns feedback visibility, independently of the shared question clock.
class GameFeedbackCubit extends Cubit<GameAnswerFeedback?> {
  GameFeedbackCubit(GameCubit game) : super(null) {
    _update(game.state);
    _subscription = game.stream.listen(_update);
  }

  late final StreamSubscription<GameState> _subscription;
  GameAnswerFeedback? _lastSeen;
  int? _questionIndex;
  Timer? _timer;

  void _update(GameState game) {
    if (_questionIndex != game.questionIndex) {
      _questionIndex = game.questionIndex;
      _timer?.cancel();
      emit(null);
    }
    final result = game.answerFeedback;
    if (result == null || result == _lastSeen) return;
    if (game.room.usesQuestionPool &&
        !game.recordedQuestionIndices.contains(result.questionIndex)) {
      return;
    }
    _lastSeen = result;
    _timer?.cancel();
    emit(result);
    if (result.questionIndex < game.questionIndex) {
      _timer = Timer(const Duration(seconds: 3), () {
        if (!isClosed) emit(null);
      });
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
