import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../room/data/firebase_room_service.dart';
import '../../../room/domain/entities/game_room.dart';
import '../../data/question_bank.dart';
import '../../domain/game_progress.dart';
import '../../domain/game_answer_feedback.dart';
import '../../domain/game_question.dart';
import 'game_state.dart';

class GameCubit extends Cubit<GameState> {
  GameCubit(this._service, GameRoom room, {int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
      super(_initialState(_service, room)) {
    _roomSubscription = _service
        .watchRoom(room.id)
        .listen(_roomChanged, onError: _streamFailed);
    _clockSubscription = _service.watchServerTimeOffset().listen((offset) {
      if (isClosed) return;
      _offsetMs = offset;
      emit(state.copyWith(clockReady: true));
      _tick();
    }, onError: _streamFailed);
    _connectionSubscription = _service.watchConnection().listen((connected) {
      if (isClosed) return;
      emit(state.copyWith(isConnected: connected));
      _tick();
    }, onError: _streamFailed);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  final FirebaseRoomService _service;
  final int Function() _nowMs;
  StreamSubscription<GameRoom>? _roomSubscription;
  StreamSubscription<int>? _clockSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _timer;
  int _offsetMs = 0;
  int _retryAtMs = 0;
  bool _isCompleting = false;
  bool _isForeground = false;
  bool _completedSetRecorded = false;
  Future<void>? _completionWrite;
  int _historyRetryAtMs = 0;

  static GameState _initialState(FirebaseRoomService service, GameRoom room) {
    List<GameQuestion> questions = const [];
    String? error;
    try {
      questions = room.usesQuestionPool
          ? room.questions
          : QuestionBank.forSet(room.questionSetId);
      if (questions.length != room.gameMode.questionCount ||
          room.startsAtMs == null ||
          (!room.isRace && room.gameplayVersion != 'sync-v1') ||
          (room.isRace && room.race == null)) {
        throw StateError('Oyun verisi eksik. Yeni bir oda oluşturun.');
      }
      if (room.usesQuestionPool) {
        for (var i = 0; i < questions.length; i++) {
          final expected = 4 + (room.gameMode.name == 'classic' ? i ~/ 2 : i);
          if (questions[i].letterCount != expected ||
              questions[i].id == null ||
              questions[i].answerId == null ||
              questions[i].clue.trim().isEmpty) {
            throw StateError(
              'Soru havuzu verisi geçersiz. Yeni bir oda oluşturun.',
            );
          }
        }
        if (questions.map((q) => q.answerId).toSet().length !=
            questions.length) {
          throw StateError('Soru setinde yinelenen cevap var.');
        }
      }
    } on StateError catch (e) {
      questions = const [];
      error = e.message;
    }
    return GameState(
      room: room,
      questions: questions,
      progress: room.progress[service.currentUserId] ?? const GameProgress(),
      currentUserId: service.currentUserId,
      errorMessage: error,
    );
  }

  Future<void> revealLetter() async {
    _tick();
    if (!state.canVote) return;
    if (state.room.isRace) {
      await _raceAction('hint');
      return;
    }
    final index = state.questionIndex;
    emit(state.copyWith(isVoting: true, clearError: true));
    try {
      final hints = await _service.requestHint(
        state.room.id,
        questionIndex: index,
        expectedRevealedCount: state.hints.revealedCount,
        requiredVotes: state.room.requiredHintVotes,
        letterCount: state.question!.letterCount,
      );
      if (isClosed) return;
      final existing = state.room.hints[index];
      if (hints != null &&
          (existing == null || hints.revealedCount >= existing.revealedCount)) {
        emit(
          state.copyWith(
            room: state.room.copyWith(
              hints: {...state.room.hints, index: hints},
            ),
          ),
        );
      }
      emit(state.copyWith(isVoting: false));
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isVoting: false,
            errorMessage: 'Harf oyu kaydedilemedi. Tekrar dene.',
          ),
        );
      }
    }
    _tick();
  }

  Future<void> requestClueHint() async {
    _tick();
    if (!state.canRequestClueHint) return;
    final index = state.questionIndex;
    final count = state.currentClueHintCount;
    emit(state.copyWith(isRequestingClueHint: true, clearError: true));
    try {
      await _service.playRace(
        state.room.id,
        action: 'clueHint',
        questionIndex: index,
        expectedHintCount: count,
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage: error is RoomServiceException
                ? error.message
                : 'İpucu alınamadı. Bağlantını kontrol edip tekrar dene.',
          ),
        );
      }
    } finally {
      if (!isClosed) emit(state.copyWith(isRequestingClueHint: false));
    }
  }

  Future<void> submitAnswer(String input) async {
    _tick();
    if (!state.canAct) return;
    if (input.trim().isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Cevabını yaz veya Bilemiyorum seçeneğini kullan.',
        ),
      );
      return;
    }
    if (GameQuestion.normalizeAnswer(input).length !=
        state.question!.letterCount) {
      emit(state.copyWith(errorMessage: 'Tüm boş harfleri doldur.'));
      return;
    }
    if (state.room.isRace) {
      await _raceAction('answer', input: input);
      return;
    }
    await _resolve(
      state.question!.accepts(input)
          ? AnswerOutcome.correct
          : AnswerOutcome.wrong,
    );
  }

  Future<void> giveUp({int? questionIndex}) async {
    _tick();
    if (questionIndex != null && questionIndex != state.questionIndex) return;
    if (state.canAct) {
      if (state.room.isRace) {
        await _raceAction('giveUp');
      } else {
        await _resolve(AnswerOutcome.wrong);
      }
    }
  }

  Future<void> _raceAction(String action, {String? input}) async {
    final voting = action == 'hint';
    emit(state.copyWith(isSaving: !voting, isVoting: voting, clearError: true));
    try {
      await _service.playRace(
        state.room.id,
        action: action,
        questionIndex: state.questionIndex,
        input: input,
        expectedRevealedCount: voting ? state.hints.revealedCount : null,
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage: error is RoomServiceException
                ? error.message
                : 'İşlem kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
          ),
        );
      }
    } finally {
      if (!isClosed) emit(state.copyWith(isSaving: false, isVoting: false));
    }
  }

  Future<bool> _resolve(AnswerOutcome outcome) async {
    final index = state.progress.questionIndex;
    if (index >= state.questions.length) return false;
    final question = state.questions[index];
    final revealedCount = state.room.hints[index]?.revealedCount ?? 0;
    final value = (question.letterCount - revealedCount) * 100;
    final correct = outcome == AnswerOutcome.correct;
    final feedback = correct
        ? 'Doğru! +$value puan.'
        : '${outcome == AnswerOutcome.timeout ? 'Süre doldu' : 'Bilemedin'}. −$value puan.';
    return _save(
      state.progress.resolve(
        state.questions,
        outcome: outcome,
        revealedCount: revealedCount,
      ),
      feedback: feedback,
      answerFeedback: GameAnswerFeedback(
        questionIndex: index,
        question: question,
        outcome: outcome,
        scoreDelta: correct ? value : -value,
      ),
    );
  }

  Future<bool> _save(
    GameProgress next, {
    required String feedback,
    required GameAnswerFeedback answerFeedback,
  }) async {
    if (state.isSaving || isClosed) return false;
    final previous = state.progress;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _service.saveProgress(state.room.id, next);
      if (isClosed) return false;
      emit(
        state.copyWith(
          progress: next,
          isSaving: false,
          feedback: feedback,
          answerFeedback: answerFeedback,
        ),
      );
      _recordCompletedSet();
      return true;
    } catch (_) {
      if (isClosed) return false;
      // Firebase streams emit pending local writes too; restore the last acknowledged state.
      emit(
        state.copyWith(
          progress: previous,
          isSaving: false,
          errorMessage:
              'İlerleme kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
        ),
      );
      _retryAtMs = _nowMs() + 3000;
      return false;
    }
  }

  void _roomChanged(GameRoom room) {
    if (isClosed || state.isLeaving) return;
    if (room.isRace) {
      final progress =
          room.progress[_service.currentUserId] ?? const GameProgress();
      final index = room.race?.questionIndex ?? 0;
      GameAnswerFeedback? feedback;
      if (index < state.questions.length) {
        final race = room.race!;
        final ownAnswer = progress.questionIndex > index;
        final outcome = race.winnerId != null
            ? race.winnerId == state.currentUserId
                  ? AnswerOutcome.correct
                  : AnswerOutcome.beaten
            : race.isResolved
            ? AnswerOutcome.timeout
            : ownAnswer
            ? progress.lastOutcome
            : null;
        if (outcome != null) {
          final value =
              (state.questions[index].letterCount -
                  (room.hints[index]?.revealedCount ?? 0)) *
              100;
          feedback = GameAnswerFeedback(
            questionIndex: index,
            question: state.questions[index],
            outcome: outcome,
            scoreDelta: outcome == AnswerOutcome.beaten
                ? 0
                : outcome == AnswerOutcome.correct
                ? value
                : progress.lastScoreDelta ?? -value,
            winnerName: race.winnerName,
          );
        }
      }
      emit(
        state.copyWith(
          room: room,
          progress: progress,
          answerFeedback: feedback,
        ),
      );
      _tick();
      return;
    }
    emit(
      state.copyWith(
        room: room,
        progress: state.isSaving
            ? state.progress
            : room.progress[_service.currentUserId] ?? const GameProgress(),
      ),
    );
    _tick();
  }

  void _tick() {
    if (isClosed || state.isLeaving) return;
    final previousIndex = state.questionIndex;
    final next = state.copyWith(serverNowMs: _nowMs() + _offsetMs);
    emit(next.copyWith(clearFeedback: next.questionIndex != previousIndex));
    _recordVisibleQuestion();
    _recordCompletedSet();
    if (state.room.isRace) {
      final race = state.room.race;
      if (race != null &&
          state.clockReady &&
          state.isConnected &&
          !state.hasExpired &&
          !_isCompleting &&
          !state.isSaving &&
          !state.isVoting &&
          _nowMs() >= _retryAtMs &&
          state.serverNowMs >= (race.nextAtMs ?? race.startedAtMs + 25000)) {
        unawaited(_syncRace());
      }
      return;
    }
    if (state.clockReady &&
        state.isConnected &&
        !state.isSaving &&
        !state.isVoting &&
        !_isCompleting &&
        _nowMs() >= _retryAtMs &&
        state.questions.isNotEmpty &&
        ((state.progress.questionIndex < state.questionIndex) ||
            (state.hasExpired && state.room.status != RoomStatus.results))) {
      unawaited(_completeRound());
    }
  }

  Future<void> _syncRace() async {
    _isCompleting = true;
    try {
      await _service.playRace(state.room.id);
      _retryAtMs = _nowMs() + 1000;
    } catch (_) {
      _retryAtMs = _nowMs() + 3000;
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage: 'Ortak soru durumu güncellenemedi. Tekrar deneniyor.',
          ),
        );
      }
    } finally {
      _isCompleting = false;
    }
  }

  void setForeground(bool foreground) {
    _isForeground = foreground;
    if (foreground) _tick();
  }

  void _recordVisibleQuestion() {
    if (!_isForeground ||
        !state.room.usesQuestionPool ||
        !state.clockReady ||
        state.isHistoryReady ||
        state.hasExpired ||
        state.isLeaving ||
        state.room.status != RoomStatus.playing ||
        state.questionIndex >= state.questions.length) {
      return;
    }
    // Visibility is session memory only; it must not consume a partially played set.
    emit(
      state.copyWith(
        recordedQuestionIndices: Set.unmodifiable({
          ...state.recordedQuestionIndices,
          state.questionIndex,
        }),
      ),
    );
  }

  void _recordCompletedSet() {
    if (_completedSetRecorded ||
        _completionWrite != null ||
        state.isLeaving ||
        !state.room.usesQuestionPool ||
        state.room.contentSetId == null ||
        state.questions.length != 14 ||
        !state.progress.finished ||
        state.recordedQuestionIndices.length != 14 ||
        _nowMs() < _historyRetryAtMs) {
      return;
    }
    _completionWrite = _saveCompletedSet();
  }

  Future<void> _saveCompletedSet() async {
    try {
      await _service.recordCompletedSet(state.room.contentSetId!);
      _completedSetRecorded = true;
      if (!isClosed) emit(state.copyWith(clearError: true));
    } catch (_) {
      _historyRetryAtMs = _nowMs() + 3000;
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage:
                'Tamamlanan set cihazda kaydedilemedi. Tekrar deneniyor.',
          ),
        );
      }
    } finally {
      _completionWrite = null;
    }
  }

  Future<void> _completeRound() async {
    _isCompleting = true;
    try {
      while (!isClosed &&
          !state.isLeaving &&
          state.isConnected &&
          state.progress.questionIndex < state.questionIndex &&
          !state.progress.finished) {
        if (!await _resolve(AnswerOutcome.timeout)) break;
      }
      if (!isClosed &&
          !state.isLeaving &&
          state.hasExpired &&
          state.progress.finished &&
          state.room.status != RoomStatus.results) {
        await _service.markResults(state.room.id);
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage: 'Sonuçlar kaydedilemedi. Tekrar deneniyor.',
          ),
        );
      }
      _retryAtMs = _nowMs() + 3000;
    } finally {
      _isCompleting = false;
    }
  }

  Future<void> leaveRoom() async {
    if (state.isLeaving) return;
    _recordCompletedSet();
    await _completionWrite;
    if (isClosed) return;
    if (state.room.usesQuestionPool &&
        state.room.contentSetId != null &&
        state.progress.finished &&
        state.recordedQuestionIndices.length == 14 &&
        !_completedSetRecorded) {
      emit(
        state.copyWith(
          errorMessage:
              'Tamamlanan set henüz kaydedilemedi. Lütfen tekrar dene.',
        ),
      );
      return;
    }
    emit(state.copyWith(isLeaving: true, clearError: true));
    try {
      await _service.leaveRoom(state.room.id);
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isLeaving: false,
            errorMessage: 'Odadan çıkılamadı. Tekrar dene.',
          ),
        );
      }
    }
  }

  void _streamFailed(Object error, StackTrace stack) {
    if (isClosed || state.isLeaving) return;
    emit(
      state.copyWith(
        isConnected: false,
        errorMessage: error is RoomServiceException
            ? error.message
            : 'Oda bağlantısı kesildi.',
      ),
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    // Stop all listeners immediately, even if the local history write is pending.
    await Future.wait([
      if (_roomSubscription != null) _roomSubscription!.cancel(),
      if (_clockSubscription != null) _clockSubscription!.cancel(),
      if (_connectionSubscription != null) _connectionSubscription!.cancel(),
      super.close(),
      ?_completionWrite,
    ]);
  }
}
