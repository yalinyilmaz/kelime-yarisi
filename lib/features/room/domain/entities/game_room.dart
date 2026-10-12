import 'package:equatable/equatable.dart';

import 'room_game_mode.dart';
import 'room_player.dart';

enum RoomStatus { lobby, countdown, playing, results }

class GameRoom extends Equatable {
  const GameRoom({
    required this.id,
    required this.name,
    required this.code,
    required this.hostId,
    required this.targetPlayerCount,
    required this.gameMode,
    required this.players,
    this.status = RoomStatus.lobby,
    this.startsAtMs,
  });

  final String id;
  final String name;
  final String code;
  final String hostId;
  final int targetPlayerCount;
  final RoomGameMode gameMode;
  final List<RoomPlayer> players;
  final RoomStatus status;
  final int? startsAtMs;

  bool get isFull => players.length >= targetPlayerCount;
  bool get everyoneIsReady =>
      isFull && players.every((player) => player.isReady && player.isOnline);

  GameRoom copyWith({
    List<RoomPlayer>? players,
    RoomStatus? status,
    int? startsAtMs,
  }) {
    return GameRoom(
      id: id,
      name: name,
      code: code,
      hostId: hostId,
      targetPlayerCount: targetPlayerCount,
      gameMode: gameMode,
      players: players ?? this.players,
      status: status ?? this.status,
      startsAtMs: startsAtMs ?? this.startsAtMs,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    code,
    hostId,
    targetPlayerCount,
    gameMode,
    players,
    status,
    startsAtMs,
  ];
}
