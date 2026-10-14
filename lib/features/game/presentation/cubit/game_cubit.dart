import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../room/data/firebase_room_service.dart';
import '../../../room/domain/entities/game_room.dart';
import '../../data/question_bank.dart';
import '../../domain/game_progress.dart';
import '../../domain/game_question.dart';
import 'game_state.dart';

class GameCubit extends Cubit<GameState> {
  GameCubit(
    this._service,
    GameRoom room, {
    Random? random,
    int Function()? nowMs,
  }) : _random = random ?? Random(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       super(_initialState(_service, room)) {
    _roomSubscription = _service
        .watchRoom(room.id)
        .listen(_roomChanged, onError: _streamFailed);
    _clockSubscription = _service.watchServerTimeOffset().listen((offset) {
      if (isClosed) return;
      _offsetMs = offset;
      emit(state.copyWith(clockReady: true, serverNowMs: _nowMs() + offset));
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
  final Random _random;
  final int Function() _nowMs;
  StreamSubscription<GameRoom>? _roomSubscription;
  StreamSubscription<int>? _clockSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _timer;
  int _offsetMs = 0;
  int _retryAtMs = 0;
  bool _isCompleting = false;

  static GameState _initialState(FirebaseRoomService service, GameRoom room) {
    List<GameQuestion> questions = const [];
    String? error;
    try {
      questions = QuestionBank.forSet(room.questionSetId);
      if (questions.length != room.gameMode.questionCount ||
          room.startsAtMs == null) {
        throw StateError('Oyun verisi eksik. Yeni bir oda oluşturun.');
      }
    } on StateError catch (e) {
      questions = const [];
      error = e.message;
    }
    return GameState(
      room: room,
      questions: questions,
      progress: room.progress[service.currentUserId] ?? const GameProgress(),
      errorMessage: error,
    );
  }

  Future<void> revealLetter() async {
    _tick();
    if (!state.canAct) return;
    final next = state.progress.revealLetter(state.question!, _random);
    if (next == state.progress) return;
    await _save(
      next,
      feedback:
          'Harf açıldı. Soru değeri ${next.valueFor(state.question!)} puan.',
    );
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
    await _resolve(correct: state.question!.accepts(input));
  }

  Future<void> giveUp() async {
    _tick();
    if (state.canAct) await _resolve(correct: false);
  }

  Future<void> _resolve({required bool correct, bool timedOut = false}) async {
    final question = state.question;
    if (question == null) return;
    final value = state.progress.valueFor(question);
    final feedback = correct
        ? 'Doğru! +$value puan.'
        : '${timedOut ? 'Süre doldu' : 'Bilemedin'}. Cevap: ${question.answer}. −$value puan.';
    await _save(
      state.progress.resolve(
        state.questions,
        correct: correct,
        timedOut: timedOut,
      ),
      feedback: feedback,
    );
  }

  Future<void> _save(GameProgress next, {required String feedback}) async {
    if (state.isSaving || isClosed) return;
    final previous = state.progress;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _service.saveProgress(state.room.id, next);
      if (isClosed) return;
      emit(state.copyWith(progress: next, isSaving: false, feedback: feedback));
    } catch (_) {
      if (isClosed) return;
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
    }
  }

  void _roomChanged(GameRoom room) {
    if (isClosed || state.isLeaving) return;
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
    emit(state.copyWith(serverNowMs: _nowMs() + _offsetMs));
    if (state.hasExpired &&
        state.isConnected &&
        !state.isSaving &&
        !_isCompleting &&
        _nowMs() >= _retryAtMs &&
        state.questions.isNotEmpty &&
        (!state.progress.finished || state.room.status != RoomStatus.results)) {
      unawaited(_completeRound());
    }
  }

  Future<void> _completeRound() async {
    _isCompleting = true;
    try {
      if (!state.progress.finished) {
        await _resolve(correct: false, timedOut: true);
      }
      if (!isClosed &&
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
    await _roomSubscription?.cancel();
    await _clockSubscription?.cancel();
    await _connectionSubscription?.cancel();
    return super.close();
  }
}
