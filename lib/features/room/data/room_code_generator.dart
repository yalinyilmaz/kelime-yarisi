import 'dart:math';

class RoomCodeGenerator {
  RoomCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  static const _letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _digits = '23456789';

  final Random _random;

  String generate() {
    final letterPart = List.generate(
      3,
      (_) => _letters[_random.nextInt(_letters.length)],
    ).join();
    final numberPart = List.generate(
      3,
      (_) => _digits[_random.nextInt(_digits.length)],
    ).join();

    return '$letterPart-$numberPart';
  }
}
