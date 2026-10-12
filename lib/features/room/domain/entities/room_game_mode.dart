enum RoomGameMode {
  quick,
  classic;

  String get label => switch (this) {
    RoomGameMode.quick => 'Hızlı',
    RoomGameMode.classic => 'Klasik',
  };

  String get description => switch (this) {
    RoomGameMode.quick => '7 soru · 2 dakika',
    RoomGameMode.classic => '14 soru · 4 dakika',
  };

  int get questionCount => switch (this) {
    RoomGameMode.quick => 7,
    RoomGameMode.classic => 14,
  };

  Duration get duration => switch (this) {
    RoomGameMode.quick => const Duration(minutes: 2),
    RoomGameMode.classic => const Duration(minutes: 4),
  };
}
