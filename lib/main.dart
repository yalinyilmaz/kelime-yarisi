import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/monitoring/error_reporter.dart';
import 'features/room/data/firebase_room_service.dart';

Future<void> main() => initializeErrorReporting(_bootstrap);

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = ErrorReportingBlocObserver();
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
  final scoreStorage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      path.join(
        (await getApplicationSupportDirectory()).path,
        'solo_score_${app.options.projectId}',
      ),
    ),
  );
  runApp(
    KelimeYarisiApp(
      soloScoreStorage: scoreStorage,
      roomService: FirebaseRoomService(
        auth: auth,
        database: database,
        functions: functions,
      ),
    ),
  );
}
