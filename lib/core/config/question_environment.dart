abstract final class QuestionEnvironment {
  static const enabled = bool.fromEnvironment('QUESTION_POOL_ENABLED');
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
}
