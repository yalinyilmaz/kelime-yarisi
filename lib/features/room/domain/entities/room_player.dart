import 'package:equatable/equatable.dart';

class RoomPlayer extends Equatable {
  const RoomPlayer({
    required this.id,
    required this.displayName,
    this.isHost = false,
    this.isReady = false,
    this.isOnline = true,
  });

  final String id;
  final String displayName;
  final bool isHost;
  final bool isReady;
  final bool isOnline;

  RoomPlayer copyWith({bool? isReady, bool? isOnline}) {
    return RoomPlayer(
      id: id,
      displayName: displayName,
      isHost: isHost,
      isReady: isReady ?? this.isReady,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [id, displayName, isHost, isReady, isOnline];
}
