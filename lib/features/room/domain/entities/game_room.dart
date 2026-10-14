import 'package:equatable/equatable.dart';

import '../../../game/domain/game_progress.dart';
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
    this.questionSetId,
    this.progress = const {},
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
  final String? questionSetId;
  final Map<String, GameProgress> progress;

  int? get endsAtMs => startsAtMs == null
      ? null
      : startsAtMs! + gameMode.duration.inMilliseconds;

  bool get isFull => players.length >= targetPlayerCount;
  bool get everyoneIsReady =>
      isFull && players.every((player) => player.isReady && player.isOnline);

  GameRoom copyWith({
    List<RoomPlayer>? players,
    RoomStatus? status,
    int? startsAtMs,
    String? questionSetId,
    Map<String, GameProgress>? progress,
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
      questionSetId: questionSetId ?? this.questionSetId,
      progress: progress ?? this.progress,
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
    questionSetId,
    progress,
  ];
}
