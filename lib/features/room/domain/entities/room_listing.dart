import 'game_room.dart';

/// Public directory metadata. Contains neither invitation codes nor member IDs.
class RoomListing {
  const RoomListing({
    required this.id,
    required this.name,
    required this.visibility,
    required this.playerCount,
    required this.capacity,
  });

  factory RoomListing.fromMap(Map map) => RoomListing(
    id: map['id'] as String,
    name: map['name'] as String,
    visibility: map['visibility'] == 'public'
        ? RoomVisibility.public
        : RoomVisibility.private,
    playerCount: (map['playerCount'] as num).toInt(),
    capacity: (map['capacity'] as num).toInt(),
  );

  final String id;
  final String name;
  final RoomVisibility visibility;
  final int playerCount;
  final int capacity;
  bool get isPrivate => visibility == RoomVisibility.private;
  bool get isFull => playerCount >= capacity;
}
