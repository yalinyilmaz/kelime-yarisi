enum RoomGameMode {
  quick,
  classic;

  String get label => switch (this) {
    RoomGameMode.quick => 'Hızlı',
    RoomGameMode.classic => 'Klasik',
  };

  String get description => switch (this) {
    RoomGameMode.quick => '7 soru · Soru başına 25 saniye',
    RoomGameMode.classic => '14 soru · Soru başına 25 saniye',
  };

  int get questionCount => switch (this) {
    RoomGameMode.quick => 7,
    RoomGameMode.classic => 14,
  };

  static const questionDuration = Duration(seconds: 25);

  Duration get duration => questionDuration * questionCount;
}
