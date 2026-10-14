import '../../game/domain/game_progress.dart';
import '../../game/domain/shared_hints.dart';
import '../domain/entities/game_room.dart';
import '../domain/entities/room_game_mode.dart';
import '../domain/entities/room_player.dart';

abstract final class FirebaseRoomMapper {
  static Map<String, Object?> toMap(GameRoom room) {
    return {
      'name': room.name,
      'code': room.code,
      'hostId': room.hostId,
      'targetPlayerCount': room.targetPlayerCount,
      'playerCount': room.players.length,
      'gameMode': room.gameMode.name,
      'status': room.status.name,
      'startsAtMs': room.startsAtMs,
      'questionSetId': room.questionSetId,
      'gameplayVersion': room.gameplayVersion,
      'createdAt': {'.sv': 'timestamp'},
      'players': {
        for (final player in room.players) player.id: playerToMap(player),
      },
    };
  }

  static Map<String, Object?> playerToMap(RoomPlayer player) {
    return {
      'displayName': player.displayName,
      'isHost': player.isHost,
      'isReady': player.isReady,
      'isOnline': player.isOnline,
      'lastSeenAt': {'.sv': 'timestamp'},
    };
  }

  static GameRoom fromMap(String roomId, Object? value) {
    final map = _asMap(value);
    final playersMap = _asMap(map['players']);
    final players =
        playersMap.entries
            .map((entry) => _playerFromMap(entry.key, entry.value))
            .toList(growable: false)
          ..sort((left, right) {
            if (left.isHost) return -1;
            if (right.isHost) return 1;
            return left.displayName.compareTo(right.displayName);
          });

    return GameRoom(
      id: roomId,
      name: map['name'] as String? ?? 'Kelime Odası',
      code: map['code'] as String? ?? _formattedCode(roomId),
      hostId: map['hostId'] as String? ?? '',
      targetPlayerCount: (map['targetPlayerCount'] as num?)?.toInt() ?? 5,
      gameMode: RoomGameMode.values.byName(
        map['gameMode'] as String? ?? RoomGameMode.classic.name,
      ),
      players: players,
      status: RoomStatus.values.byName(
        map['status'] as String? ?? RoomStatus.lobby.name,
      ),
      startsAtMs: (map['startsAtMs'] as num?)?.toInt(),
      questionSetId: map['questionSetId'] as String?,
      gameplayVersion: map['gameplayVersion'] as String?,
      hints: Map.unmodifiable(
        _asMap(map['hints']).map(
          (index, value) =>
              MapEntry(int.parse(index), SharedHints.fromMap(value)),
        ),
      ),
      progress: Map.unmodifiable(
        _asMap(map['progress'])
            .map((uid, value) => MapEntry(uid, GameProgress.fromMap(value))),
      ),
    );
  }

  static RoomPlayer _playerFromMap(String id, Object? value) {
    final map = _asMap(value);
    return RoomPlayer(
      id: id,
      displayName: map['displayName'] as String? ?? 'Oyuncu',
      isHost: map['isHost'] as bool? ?? false,
      isReady: map['isReady'] as bool? ?? false,
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }

  static Map<String, Object?> _asMap(Object? value) {
    // RTDB represents dense numeric children (hints/0, hints/1, ...) as a list.
    if (value is List) {
      return {
        for (var i = 0; i < value.length; i++)
          if (value[i] != null) '$i': value[i],
      };
    }
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String _formattedCode(String roomId) {
    if (roomId.length != 6) return roomId.toUpperCase();
    return '${roomId.substring(0, 3)}-${roomId.substring(3)}'.toUpperCase();
  }
}
