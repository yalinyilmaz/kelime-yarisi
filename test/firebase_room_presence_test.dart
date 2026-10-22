import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/game/data/question_history_store.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';

void main() {
  late _Database database;
  late _History history;
  late FirebaseRoomService service;
  setUp(() {
    database = _Database();
    history = _History();
    service = FirebaseRoomService(
      auth: _Auth(),
      database: database,
      functions: _Functions(database),
      questionHistory: history,
    );
  });
  tearDown(() async {
    await service.dispose();
    for (final stream in database.streams) {
      await stream.close();
    }
  });

  test(
    'concurrent and repeated starts keep exactly one presence subscription',
    () async {
      await Future.wait([
        service.beginPresence('abc234'),
        service.beginPresence('abc234'),
      ]);
      await service.beginPresence('abc234');
      expect(database.streams.length, 1);
      expect(database.streams.single.hasListener, isTrue);
      await Future.wait([service.dispose(), service.dispose()]);
      expect(database.streams.single.hasListener, isFalse);
      expect(history.closes, 1);
    },
  );

  test('a slow cancellation cannot install an older room listener over a newer one', () async {
    await service.beginPresence('abc234');
    final gate = Completer<void>();
    database.cancelGate = gate.future;
    final older = service.beginPresence('def234');
    await service.beginPresence('ghj234');
    gate.complete();
    await older;
    expect(database.streams.length, 2);
    expect(database.streams.first.hasListener, isFalse);
    expect(database.streams.last.hasListener, isTrue);
  });

  test(
    'leaving while a new listener is pending prevents its late installation',
    () async {
      await service.beginPresence('abc234');
      final gate = Completer<void>();
      database.cancelGate = gate.future;
      final pending = service.beginPresence('def234');
      await service.leaveRoom('def234');
      gate.complete();
      await pending;
      expect(database.streams.length, 1);
      expect(database.streams.single.hasListener, isFalse);
    },
  );

  test(
    'dispose cancels a pending replacement and never reopens a listener',
    () async {
      await service.beginPresence('abc234');
      final gate = Completer<void>();
      database.cancelGate = gate.future;
      final pending = service.beginPresence('def234');
      await service.dispose();
      gate.complete();
      await pending;
      await service.beginPresence('ghj234');
      expect(database.streams.length, 1);
      expect(database.streams.single.hasListener, isFalse);
      expect(history.closes, 1);
    },
  );

  test(
    'leaving an old room preserves the current room presence listener',
    () async {
      await service.beginPresence('abc234');
      await service.beginPresence('def234');
      await service.leaveRoom('abc234');
      expect(database.streams.last.hasListener, isTrue);
    },
  );

  test(
    'late reconnect registration cannot mark a disposed room online',
    () async {
      final gate = Completer<void>();
      database.disconnectGate = gate.future;
      await service.beginPresence('abc234');
      database.streams.single.add(_Event());
      await service.dispose();
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(database.onlineWrites, 0);
      expect(history.closes, 1);
    },
  );

  test('offline network acknowledgement does not hold local stream/database cleanup', () async {
    final gate = Completer<void>();
    database.writeGate = gate.future;
    await service.beginPresence('abc234');
    await service.dispose();
    expect(database.streams.single.hasListener, isFalse);
    expect(history.closes, 1);
    gate.complete();
  });

  test(
    'explicit leave calls the server once and stops presence after success',
    () async {
      await service.beginPresence('abc234');
      await service.leaveRoom('abc234');
      expect(database.leaveRequests, [
        {'roomId': 'abc234'},
      ]);
      expect(database.streams.single.hasListener, isFalse);
      expect(database.disconnectCancels, 1);
    },
  );

  test('failed leave keeps presence alive so the player can retry', () async {
    await service.beginPresence('abc234');
    database.leaveFailure = true;
    await expectLater(
      service.leaveRoom('abc234'),
      throwsA(isA<RoomServiceException>()),
    );
    expect(database.streams.single.hasListener, isTrue);
    expect(database.disconnectCancels, 0);
  });

  test(
    'a pending disconnect cancellation never blocks successful exit cleanup',
    () async {
      final gate = Completer<void>();
      database.disconnectCancelGate = gate.future;
      await service.beginPresence('abc234');
      await service.leaveRoom('abc234');
      expect(database.streams.single.hasListener, isFalse);
      gate.complete();
    },
  );
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.database);
  final _Database database;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'leaveQuestionRoom');
    return _Callable(database);
  }
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.database);
  final _Database database;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    database.leaveRequests.add(parameters);
    if (database.leaveFailure) {
      throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
    }
    return _Result<T>();
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  @override
  T get data => {'committed': true} as T;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'device-user';
}

class _History extends Fake implements QuestionHistoryStore {
  int closes = 0;
  @override
  Future<void> close() async {
    closes++;
  }
}

class _Database extends Fake implements FirebaseDatabase {
  final streams = <StreamController<DatabaseEvent>>[];
  Future<void>? cancelGate;
  Future<void>? disconnectGate;
  Future<void>? writeGate;
  Future<void>? disconnectCancelGate;
  bool leaveFailure = false;
  final leaveRequests = <Object?>[];
  int disconnectCancels = 0;
  int onlineWrites = 0;
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path ?? '');
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  DatabaseReference child(String path) =>
      _Reference(database, '${this.path}/$path');
  @override
  Stream<DatabaseEvent> get onValue {
    final controller = StreamController<DatabaseEvent>(
      sync: true,
      onCancel: () => database.cancelGate,
    );
    database.streams.add(controller);
    return controller.stream;
  }

  @override
  Future<DataSnapshot> get() async => _Snapshot(null);
  @override
  OnDisconnect onDisconnect() => _Disconnect(database);
  @override
  Future<void> update(Map<String, Object?> value) async {
    if (value['isOnline'] == true) database.onlineWrites++;
    await database.writeGate;
  }
}

class _Disconnect extends Fake implements OnDisconnect {
  _Disconnect(this.database);
  final _Database database;
  @override
  Future<void> update(Map<String, Object?> value) async =>
      await database.disconnectGate;
  @override
  Future<void> cancel() async {
    database.disconnectCancels++;
    await database.disconnectCancelGate;
  }
}

class _Event extends Fake implements DatabaseEvent {
  @override
  DataSnapshot get snapshot => _Snapshot(true);
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}
