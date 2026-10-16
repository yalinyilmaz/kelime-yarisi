import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'features/room/data/firebase_room_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp();
  final auth = FirebaseAuth.instanceFor(app: app);
  final database = FirebaseDatabase.instanceFor(app: app);
  final functions = FirebaseFunctions.instanceFor(
    app: app,
    region: 'europe-west1',
  );
  await FirebaseAppCheck.instanceFor(app: app).activate(
    providerAndroid: const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );
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
