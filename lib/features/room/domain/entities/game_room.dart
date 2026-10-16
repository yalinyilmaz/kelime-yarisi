import 'package:equatable/equatable.dart';

import '../../../game/domain/game_progress.dart';
import '../../../game/domain/game_question.dart';
import '../../../game/domain/shared_hints.dart';
import '../../../game/domain/question_race.dart';
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
    this.gameplayVersion,
    this.hints = const {},
    this.questions = const [],
    this.questionEngine = 'demo-v1',
    this.questionOrigin = 'example',
    this.race,
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
  final String? gameplayVersion;
  final Map<int, SharedHints> hints;
  final List<GameQuestion> questions;
  final String questionEngine;
  final String questionOrigin;
  final QuestionRace? race;
  bool get isRace => gameplayVersion == 'race-v1';
  bool get usesQuestionPool => questionSetId?.startsWith('pool-v1:') ?? false;

  int get requiredHintVotes => targetPlayerCount <= 3 ? 1 : 2;

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
    Map<int, SharedHints>? hints,
    String? gameplayVersion,
    QuestionRace? race,
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
      hints: hints ?? this.hints,
      questions: questions,
      questionEngine: questionEngine,
      questionOrigin: questionOrigin,
      gameplayVersion: gameplayVersion ?? this.gameplayVersion,
      race: race ?? this.race,
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
    gameplayVersion,
    hints,
    questions,
    questionEngine,
    questionOrigin,
    race,
  ];
}
