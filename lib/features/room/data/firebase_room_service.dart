import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/question_environment.dart';
import '../../game/data/question_history_store.dart';
import '../../game/domain/question_capacity.dart';
import '../../game/domain/game_progress.dart';
import '../../game/domain/shared_hints.dart';
import '../domain/entities/game_room.dart';
import '../domain/entities/room_game_mode.dart';
import '../domain/entities/room_player.dart';
import 'firebase_room_mapper.dart';
import 'room_code_generator.dart';

class FirebaseRoomService {
  FirebaseRoomService({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    RoomCodeGenerator? codeGenerator,
    this.functions,
    this.appCheck,
    QuestionHistoryStore? questionHistory,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance,
       _codeGenerator = codeGenerator ?? RoomCodeGenerator(),
       _questionHistory = questionHistory ?? QuestionHistoryStore();

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final RoomCodeGenerator _codeGenerator;
  final FirebaseFunctions? functions;
  final FirebaseAppCheck? appCheck;
  final QuestionHistoryStore _questionHistory;

  FirebaseFunctions get _questionFunctions =>
      functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  StreamSubscription<DatabaseEvent>? _presenceSubscription;
  String? _presenceRoomId;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<void> ensureSignedIn() async {
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
  }

  Future<GameRoom> createRoom({
    required String displayName,
    required String roomName,
    required int targetPlayerCount,
    required RoomGameMode gameMode,
  }) async {
    if (gameMode != RoomGameMode.classic) {
      throw const RoomServiceException(
        'unsupported-mode',
        'Yalnız klasik oyun destekleniyor.',
      );
    }
    await ensureSignedIn();
    final uid = _requireUserId();

    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _codeGenerator.generate();
      final roomId = _roomId(code);
      final player = RoomPlayer(
        id: uid,
        displayName: displayName.trim(),
        isHost: true,
      );
      final room = GameRoom(
        id: roomId,
        name: roomName.trim(),
        code: code,
        hostId: uid,
        targetPlayerCount: targetPlayerCount,
        gameMode: gameMode,
        players: [player],
        questionEngine: QuestionEnvironment.enabled ? 'pool-v1' : 'demo-v1',
      );
      try {
        await _roomRef(roomId).set(FirebaseRoomMapper.toMap(room));
        await beginPresence(roomId);
        return room;
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') continue;
        rethrow;
      }
    }

    throw const RoomServiceException(
      'room-code-unavailable',
      'Oda kodu üretilemedi. Lütfen tekrar deneyin.',
    );
  }

  Future<GameRoom> joinRoom({
    required String displayName,
    required String roomCode,
  }) async {
    await ensureSignedIn();
    final uid = _requireUserId();
    final roomId = _roomId(roomCode);
    final roomRef = _roomRef(roomId);
    final player = RoomPlayer(id: uid, displayName: displayName.trim());

    try {
      await roomRef.update({
        'players/$uid': FirebaseRoomMapper.playerToMap(player),
        'playerCount': ServerValue.increment(1),
      });
      final snapshot = await roomRef.get();
      if (!snapshot.exists) {
        throw const RoomServiceException(
          'room-not-found',
          'Bu kodla eşleşen bir oda bulunamadı.',
        );
      }

      await beginPresence(roomId);
      return FirebaseRoomMapper.fromMap(roomId, snapshot.value);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const RoomServiceException(
          'join-rejected',
          'Oda bulunamadı, dolu veya oyun başlamış olabilir.',
        );
      }
      rethrow;
    }
  }

  Stream<GameRoom> watchRoom(String roomId) {
    return _roomRef(roomId).onValue.map((event) {
      if (!event.snapshot.exists) {
        throw const RoomServiceException(
          'room-closed',
          'Oda sahibi odayı kapattı.',
        );
      }
      return FirebaseRoomMapper.fromMap(roomId, event.snapshot.value);
    });
  }

  Stream<int> watchServerTimeOffset() {
    return _database
        .ref('.info/serverTimeOffset')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
  }

  Stream<bool> watchConnection() => _database
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  Future<void> saveProgress(String roomId, GameProgress progress) =>
      _roomRef(roomId)
          .child('progress/${_requireUserId()}')
          .set(progress.toMap());

  Future<void> markResults(String roomId) =>
      _roomRef(roomId).child('status').set(RoomStatus.results.name);

  Future<void> playRace(
    String roomId, {
    String action = 'sync',
    int? questionIndex,
    String? input,
    int? expectedRevealedCount,
    int? expectedHintCount,
  }) async {
    await _callQuestionFunction('playRace', {
      'roomId': roomId,
      'action': action,
      'questionIndex': ?questionIndex,
      'input': ?input,
      'expectedRevealedCount': ?expectedRevealedCount,
      'expectedHintCount': ?expectedHintCount,
    });
  }

  Future<SharedHints?> requestHint(
    String roomId, {
    required int questionIndex,
    required int expectedRevealedCount,
    required int requiredVotes,
    required int letterCount,
  }) async {
    final uid = _requireUserId();
    final hintRef = _roomRef(roomId).child('hints/$questionIndex');
    final snapshot = await hintRef.get();
    final result = await hintRef.runTransaction((value) {
      // The first callback can be null even after get(); retries use server data.
      final hints = SharedHints.fromMap(value ?? snapshot.value);
      if (hints.revealedCount != expectedRevealedCount) {
        return Transaction.abort();
      }
      final next = hints.vote(
        uid,
        requiredVotes: requiredVotes,
        letterCount: letterCount,
      );
      return next == null
          ? Transaction.abort()
          : Transaction.success(next.toMap(questionIndex));
    }, applyLocally: false);
    return result.committed ? SharedHints.fromMap(result.snapshot.value) : null;
  }

  Future<void> setReady(String roomId, {required bool isReady}) async {
    final uid = _requireUserId();
    if (isReady && await _usesQuestionPool(roomId)) {
      await prepareQuestionHistory(roomId);
    }
    await _roomRef(roomId).child('players/$uid').update({
      'isReady': isReady,
      'isOnline': true,
      'lastSeenAt': ServerValue.timestamp,
    });
  }

  Future<void> startCountdown(
    String roomId, {
    required int serverTimeOffsetMs,
    required RoomGameMode gameMode,
    required String questionEngine,
  }) async {
    // The lobby already knows the engine; do not route through a second cache read.
    if (questionEngine == 'pool-v1') {
      await prepareQuestionHistory(roomId);
      await _callQuestionFunction('startQuestionGame', {
        'roomId': roomId,
        'debugSolo': kDebugMode,
      });
      return;
    }
    if (questionEngine != 'demo-v1') {
      throw const RoomServiceException(
        'unsupported-question-engine',
        'Odanın soru kaynağı desteklenmiyor. Yeni bir oda oluşturun.',
      );
    }
    await _callQuestionFunction('startDemoRaceGame', {
      'roomId': roomId,
      'debugSolo': kDebugMode,
    });
  }

  Future<void> markPlaying(String roomId) async {
    if ((await _roomRef(roomId).child('gameplayVersion').get()).value ==
        'race-v1') {
      await playRace(roomId);
      return;
    }
    await _roomRef(roomId).child('status').set(RoomStatus.playing.name);
  }

  Future<void> beginPresence(String roomId) async {
    await _presenceSubscription?.cancel();
    _presenceRoomId = roomId;
    _presenceSubscription = _database.ref('.info/connected').onValue.listen((
      event,
    ) {
      if (event.snapshot.value == true) {
        unawaited(_registerConnectedPresence(roomId));
      }
    });
  }

  Future<void> leaveRoom(String roomId) async {
    final uid = _requireUserId();
    await _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _presenceRoomId = null;

    DataSnapshot roomSnapshot;
    try {
      roomSnapshot = await _roomRef(roomId).get();
    } on FirebaseException catch (error) {
      // A deleted room revokes read access before its listener can deliver null.
      if (error.code == 'permission-denied') return;
      rethrow;
    }
    if (!roomSnapshot.exists) return;
    final room = FirebaseRoomMapper.fromMap(roomId, roomSnapshot.value);
    final playerRef = _roomRef(roomId).child('players/$uid');
    await playerRef.onDisconnect().cancel();
    if (room.hostId == uid) {
      await _roomRef(roomId).remove();
    } else {
      await _roomRef(roomId).update({
        'players/$uid': null,
        'playerCount': ServerValue.increment(-1),
      });
    }
  }

  Future<void> dispose() async {
    await _presenceSubscription?.cancel();
    final roomId = _presenceRoomId;
    if (roomId != null && currentUserId.isNotEmpty) {
      await _roomRef(roomId)
          .child('players/$currentUserId')
          .update({'isOnline': false, 'lastSeenAt': ServerValue.timestamp});
    }
    await _questionHistory.close();
  }

  Future<void> recordCompletedSet(String setId) =>
      _questionHistory.recordCompleted(setId);

  Future<bool> _usesQuestionPool(String roomId) async =>
      (await _roomRef(roomId).child('questionEngine').get()).value == 'pool-v1';

  Future<Map<String, dynamic>> prepareQuestionHistory(String roomId) async {
    final data = await _callQuestionFunction('prepareQuestionHistory', {
      'roomId': roomId,
      'history': await _questionHistory.snapshot(),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Object?> _callQuestionFunction(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final callable = _questionFunctions.httpsCallable(name);
      try {
        return (await callable.call(data)).data;
      } on FirebaseFunctionsException catch (error) {
        if (error.code != 'unauthenticated') rethrow;
        // Reuse the current identity. A new anonymous user would lose the room.
        final verifier =
            appCheck ??
            FirebaseAppCheck.instanceFor(app: _questionFunctions.app);
        String? token;
        try {
          token = await verifier.getToken(true);
        } on FirebaseException {
          // Native errors can contain credentials; never forward them to UI.
        }
        if (token == null || token.isEmpty) {
          throw RoomServiceException(
            'app-check-failed',
            kDebugMode && defaultTargetPlatform == TargetPlatform.iOS
                ? 'Uygulama doğrulanamadı. iOS debug sürümünde güncel App Check debug tokenını doğru Firebase uygulamasına kaydedin.'
                : 'Uygulama doğrulanamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
          );
        }
        // Retry only once, after the SDK has cached a fresh App Check token.
        return (await callable.call(data)).data;
      }
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      String message = error.message ?? 'Soru servisine bağlanılamadı.';
      if (error.code == 'unauthenticated') {
        message = 'Oturum veya uygulama doğrulanamadı. Uygulamayı kapatıp tekrar açın.';
      }
      if (error.code == 'resource-exhausted' && details is Map) {
        final capacity = details['capacity'];
        final lengths = capacity is Map ? capacity['blockedLengths'] : null;
        message = details['reason'] == 'sets-exhausted'
            ? 'Tüm oyuncular için yeni, tamamlanmış bir set kalmadı. Yeni setler yayımlandığında tekrar deneyin.'
            : lengths is List && lengths.isNotEmpty
            ? '${lengths.join(', ')} harfli görülmemiş cevaplar yetersiz. Yeni içerik gerekli.'
            : 'Konu, zorluk veya benzer kelime sınırlarına uygun yeni set bulunamadı.';
      }
      final capacity = details is Map ? details['capacity'] : null;
      throw RoomServiceException(
        error.code,
        message,
        capacity: capacity is Map ? QuestionCapacity.fromMap(capacity) : null,
      );
    }
  }

  Future<void> _registerConnectedPresence(String roomId) async {
    final uid = _requireUserId();
    final playerRef = _roomRef(roomId).child('players/$uid');
    await playerRef.onDisconnect().update({
      'isOnline': false,
      'lastSeenAt': ServerValue.timestamp,
    });
    await playerRef.update({
      'isOnline': true,
      'lastSeenAt': ServerValue.timestamp,
    });
  }

  DatabaseReference _roomRef(String roomId) => _database.ref('rooms/$roomId');

  String _requireUserId() {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw const RoomServiceException(
        'not-authenticated',
        'Firebase oturumu açılamadı.',
      );
    }
    return uid;
  }

  String _roomId(String code) =>
      code.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
}

class RoomServiceException implements Exception {
  const RoomServiceException(this.code, this.message, {this.capacity});

  final String code;
  final String message;
  final QuestionCapacity? capacity;

  @override
  String toString() => message;
}
