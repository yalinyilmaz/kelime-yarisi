import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/config/question_environment.dart';
import 'features/room/data/firebase_room_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final useEmulators = QuestionEnvironment.useEmulators;
  if (useEmulators &&
      (!kDebugMode ||
          const String.fromEnvironment('FLUTTER_APP_FLAVOR') != 'dev')) {
    throw StateError(
      'Firebase emulators yalnızca dev debug modunda kullanılabilir.',
    );
  }
  // A named demo app isolates emulator auth and cached data from native dev/prod.
  final app = useEmulators
      ? await Firebase.initializeApp(
          name: 'question-pool-emulator',
          options: FirebaseOptions(
            // Native Installations validates key syntax even for a demo app.
            // This placeholder is not a credential and cannot access Firebase.
            apiKey: 'AIzaSy000000000000000000000000000000000',
            appId:
                '1:1234567890:${defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'}:abcdef123456',
            messagingSenderId: '1234567890',
            projectId: 'demo-kelime-yarisi',
            databaseURL:
                'https://demo-kelime-yarisi-default-rtdb.firebaseio.com',
          ),
        )
      : await Firebase.initializeApp();
  final auth = FirebaseAuth.instanceFor(app: app);
  final database = FirebaseDatabase.instanceFor(app: app);
  final functions = FirebaseFunctions.instanceFor(
    app: app,
    region: 'europe-west1',
  );
  if (useEmulators) {
    final host = QuestionEnvironment.emulatorHost;
    await auth.useAuthEmulator(host, 9099);
    database.useDatabaseEmulator(host, 9000);
    functions.useFunctionsEmulator(host, 5001);
  }
  if (!useEmulators) {
    await FirebaseAppCheck.instanceFor(app: app).activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
  }
  database.setPersistenceEnabled(true);
  runApp(
    KelimeYarisiApp(
      roomService: FirebaseRoomService(
        auth: auth,
        database: database,
        functions: functions,
      ),
    ),
  );
}
