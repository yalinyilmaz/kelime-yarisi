import '../../../../core/monitoring/error_reporter.dart';

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../game/domain/game_answer_feedback.dart';
import '../../../game/domain/game_progress.dart';
import '../../../game/domain/game_question.dart';
import '../../../game/presentation/audio/game_sound_controller.dart';
import '../../../room/data/firebase_room_service.dart';
import 'solo_best_score_cubit.dart';
import 'solo_game_state.dart';

class SoloGameCubit extends Cubit<SoloGameState> {
  SoloGameCubit(
    this._service,
    this._best, {
    GameSoundController? sounds,
    int Function()? nowMs,
  }) : _sounds = sounds ?? GameSoundController(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       super(const SoloGameState()) {
    unawaited(_sounds.initialize());
  }

  final FirebaseRoomService _service;
  final SoloBestScoreCubit _best;
  final GameSoundController _sounds;
  bool _foreground = true;
  bool _speechListening = false;
  final int Function() _nowMs;
  Timer? _timer;
  Timer? _feedbackTimer;
  int? _deadlineMs;
  Future<void>? _completionWrite;

  Future<void> start() async {
    if (isClosed ||
        ![SoloGamePhase.idle, SoloGamePhase.failed].contains(state.phase)) {
      return;
    }
    emit(state.copyWith(phase: SoloGamePhase.loading, clearError: true));
    try {
      final set = await _service.loadSoloSet();
      if (isClosed) return;
      _deadlineMs = _nowMs() + SoloGameState.duration.inMilliseconds;
      emit(state.copyWith(phase: SoloGamePhase.playing, set: set));
      _timer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => refreshTime(),
      );
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'solo_game_cubit.start',
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: SoloGamePhase.failed,
            errorMessage: error is RoomServiceException
                ? error.message
                : 'Soru seti alınamadı. Tekrar dene.',
          ),
        );
      }
    }
  }

  void refreshTime() {
    if (isClosed ||
        state.isLeaving ||
        state.phase != SoloGamePhase.playing ||
        state.progress.finished) {
      return;
    }
    final seconds = ((_deadlineMs! - _nowMs()) / 1000).ceil().clamp(
      0,
      SoloGameState.duration.inSeconds,
    );
    if (seconds == 0) {
      _timer?.cancel();
      _feedbackTimer?.cancel();
      emit(
        state.copyWith(
          phase: SoloGamePhase.expired,
          remainingSeconds: 0,
          feedback:
              state.feedback ??
              GameAnswerFeedback(
                questionIndex: state.questionIndex,
                question: state.question!,
                outcome: AnswerOutcome.timeout,
                scoreDelta: 0,
              ),
        ),
      );
      unawaited(saveCompletion());
    } else if (seconds != state.remainingSeconds) {
      if (seconds <= 5) _sounds.playClockTick();
      emit(state.copyWith(remainingSeconds: seconds));
    }
  }

  void submitAnswer(String input) {
    refreshTime();
    if (!state.canAct) return;
    if (GameQuestion.normalizeAnswer(input).length !=
        state.question!.letterCount) {
      emit(state.copyWith(errorMessage: 'Tüm boş harfleri doldur.'));
      return;
    }
    _resolve(
      state.question!.accepts(input)
          ? AnswerOutcome.correct
          : AnswerOutcome.wrong,
    );
  }

  void giveUp(int questionIndex) {
    refreshTime();
    if (state.canAct && state.questionIndex == questionIndex) {
      _resolve(AnswerOutcome.wrong);
    }
  }

  void _resolve(AnswerOutcome outcome) {
    final correct = outcome == AnswerOutcome.correct;
    final result = GameAnswerFeedback(
      questionIndex: state.questionIndex,
      question: state.question!,
      outcome: outcome,
      scoreDelta: correct ? state.questionValue : -state.questionValue,
    );
    final progress = state.progress.resolve(
      state.set!.questions,
      outcome: outcome,
      revealedCount: state.revealedCount,
    );
    emit(
      state.copyWith(progress: progress, feedback: result, clearError: true),
    );
    _sounds.playAnswerFeedback(correct);
    if (progress.finished) {
      _timer?.cancel();
      unawaited(saveCompletion());
    }
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (isClosed || state.isLeaving) return;
      emit(
        state.copyWith(
          clearFeedback: true,
          revealedCount: 0,
          phase: state.progress.finished
              ? SoloGamePhase.completed
              : SoloGamePhase.playing,
        ),
      );
      refreshTime();
    });
  }

  void revealLetter() {
    refreshTime();
    if (!state.canRevealLetter) return;
    emit(
      state.copyWith(revealedCount: state.revealedCount + 1, clearError: true),
    );
    _sounds.playLetterReveal();
  }

  void requestHint() {
    refreshTime();
    if (!state.canRequestHint) return;
    emit(
      state.copyWith(
        hintUsage: Map.unmodifiable({
          ...state.hintUsage,
          state.questionIndex: state.currentHintCount + 1,
        }),
        clearError: true,
      ),
    );
  }

  Future<void> saveCompletion() {
    if (isClosed ||
        (!state.progress.finished && state.phase != SoloGamePhase.expired) ||
        state.completionSaved) {
      return Future<void>.value();
    }
    return _completionWrite ??= _persistCompletion().whenComplete(() {
      _completionWrite = null;
    });
  }

  Future<void> _persistCompletion() async {
    emit(state.copyWith(isSavingCompletion: true, clearError: true));
    try {
      if (state.progress.finished) {
        await _service.recordCompletedSet(state.set!.id);
      }
      _best.recordCompletedScore(state.progress.score);
      if (!isClosed) {
        emit(state.copyWith(isSavingCompletion: false, completionSaved: true));
      }
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'solo_game_cubit._persistCompletion',
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            isSavingCompletion: false,
            errorMessage:
                'Oyun kaydedilemedi. Çıkmadan önce kaydı tekrar dene.',
          ),
        );
      }
    }
  }

  void toggleSound() {
    if (isClosed) return;
    emit(state.copyWith(soundEnabled: !state.soundEnabled));
    unawaited(_sounds.setEnabled(state.soundEnabled));
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    unawaited(_sounds.setForeground(_foreground && !_speechListening));
    if (foreground) refreshTime();
  }

  Future<void> setSpeechListening(bool listening) {
    _speechListening = listening;
    return _sounds.setForeground(_foreground && !listening);
  }

  void leave() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    emit(state.copyWith(isLeaving: true));
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    await Future.wait([super.close(), _sounds.dispose(), ?_completionWrite]);
  }
}
