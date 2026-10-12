import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance,
       _codeGenerator = codeGenerator ?? RoomCodeGenerator();

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final RoomCodeGenerator _codeGenerator;

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
      );
      final result = await _roomRef(roomId).runTransaction(
        (currentValue) => currentValue == null
            ? Transaction.success(FirebaseRoomMapper.toMap(room))
            : Transaction.abort(),
        applyLocally: false,
      );
      if (!result.committed) continue;

      await beginPresence(roomId);
      return FirebaseRoomMapper.fromMap(roomId, result.snapshot.value);
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
    final snapshot = await roomRef.get();
    if (!snapshot.exists) {
      throw const RoomServiceException(
        'room-not-found',
        'Bu kodla eşleşen bir oda bulunamadı.',
      );
    }

    RoomServiceException? rejection;
    final result = await roomRef.runTransaction((currentValue) {
      if (currentValue == null) {
        rejection = const RoomServiceException(
          'room-not-found',
          'Bu kodla eşleşen bir oda bulunamadı.',
        );
        return Transaction.abort();
      }

      final currentRoom = FirebaseRoomMapper.fromMap(roomId, currentValue);
      RoomPlayer? existingPlayer;
      for (final player in currentRoom.players) {
        if (player.id == uid) {
          existingPlayer = player;
          break;
        }
      }
      if (currentRoom.status != RoomStatus.lobby && existingPlayer == null) {
        rejection = const RoomServiceException(
          'game-already-started',
          'Bu odadaki oyun başlamış.',
        );
        return Transaction.abort();
      }
      if (currentRoom.isFull && existingPlayer == null) {
        rejection = const RoomServiceException('room-full', 'Bu oda dolu.');
        return Transaction.abort();
      }

      final roomData = _copyMap(currentValue);
      final playersData = _copyMap(roomData['players']);
      final player = RoomPlayer(
        id: uid,
        displayName: displayName.trim(),
        isHost: existingPlayer?.isHost ?? false,
      );
      playersData[uid] = FirebaseRoomMapper.playerToMap(player);
      roomData['players'] = playersData;
      return Transaction.success(roomData);
    }, applyLocally: false);
    if (!result.committed) {
      throw rejection ??
          const RoomServiceException(
            'join-failed',
            'Odaya katılım tamamlanamadı.',
          );
    }

    await beginPresence(roomId);
    return FirebaseRoomMapper.fromMap(roomId, result.snapshot.value);
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

  Future<void> setReady(String roomId, {required bool isReady}) async {
    final uid = _requireUserId();
    await _roomRef(roomId).child('players/$uid').update({
      'isReady': isReady,
      'isOnline': true,
      'lastSeenAt': ServerValue.timestamp,
    });
  }

  Future<void> startCountdown(
    String roomId, {
    required int serverTimeOffsetMs,
  }) async {
    final startsAtMs =
        DateTime.now().millisecondsSinceEpoch + serverTimeOffsetMs + 4000;
    await _roomRef(
      roomId,
    ).update({'startsAtMs': startsAtMs, 'status': RoomStatus.countdown.name});
  }

  Future<void> markPlaying(String roomId) async {
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

    final roomSnapshot = await _roomRef(roomId).get();
    if (!roomSnapshot.exists) return;
    final room = FirebaseRoomMapper.fromMap(roomId, roomSnapshot.value);
    final playerRef = _roomRef(roomId).child('players/$uid');
    await playerRef.onDisconnect().cancel();
    if (room.hostId == uid) {
      await _roomRef(roomId).remove();
    } else {
      await playerRef.remove();
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

  Map<String, Object?> _copyMap(Object? value) {
    if (value is! Map) return {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}

class RoomServiceException implements Exception {
  const RoomServiceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
