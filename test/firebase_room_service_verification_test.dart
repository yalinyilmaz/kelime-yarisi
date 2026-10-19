import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/features/room/data/firebase_room_service.dart';
import 'package:kelime_yarisi/features/game/data/question_history_store.dart';
import 'package:kelime_yarisi/features/game/data/question_bank.dart';
import 'package:kelime_yarisi/features/room/domain/entities/room_game_mode.dart';

void main() {
  late _Callable callable;
  late _AppCheck appCheck;
  late FirebaseRoomService service;
  late _Functions functions;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    callable = _Callable();
    appCheck = _AppCheck();
    functions = _Functions(callable);
    service = FirebaseRoomService(
      auth: _Auth(),
      database: _Database(),
      functions: functions,
      appCheck: appCheck,
      questionHistory: _History(),
    );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('solo uses the same local completion history and decodes one full set with two hints', () async {
    callable.result = {
      'id': 'unseen-set',
      'questions': [
        for (final (index, q) in QuestionBank.forSet('classic-v1').indexed)
          {
            'id': 'q_$index',
            'answerId': 'a_$index',
            'clue': q.clue,
            'answer': q.answer,
            'hints': q.hints,
          },
      ],
    };
    final set = await service.loadSoloSet();
    expect(functions.names, ['getSoloQuestionSet']);
    expect(callable.requests.single, {
      'history': {
        'completedSetIds': ['completed-set'],
      },
    });
    expect(set.id, 'unseen-set');
    expect(set.questions, hasLength(14));
    expect(set.questions.every((q) => q.hints.length == 2), isTrue);
  });

  test(
    'pool lobby prepares history and starts pool game with debug solo enabled',
    () async {
      await service.startCountdown(
        'room',
        serverTimeOffsetMs: 0,
        gameMode: RoomGameMode.classic,
        questionEngine: 'pool-v1',
      );
      expect(functions.names, ['prepareQuestionHistory', 'startQuestionGame']);
      expect(callable.requests.last, {'roomId': 'room', 'debugSolo': true});
      expect((callable.requests.first as Map)['history'], {
        'completedSetIds': ['completed-set'],
      });
    },
  );

  test('demo lobby calls only the demo starter', () async {
    await service.startCountdown(
      'room',
      serverTimeOffsetMs: 0,
      gameMode: RoomGameMode.classic,
      questionEngine: 'demo-v1',
    );
    expect(functions.names, ['startDemoRaceGame']);
  });

  test('unknown engines never silently fall back to demo', () async {
    await expectLater(
      service.startCountdown(
        'room',
        serverTimeOffsetMs: 0,
        gameMode: RoomGameMode.classic,
        questionEngine: 'unknown',
      ),
      throwsA(
        isA<RoomServiceException>().having(
          (error) => error.code,
          'code',
          'unsupported-question-engine',
        ),
      ),
    );
    expect(functions.names, isEmpty);
  });

  test('successful calls do not force App Check refresh', () async {
    await service.playRace('room');
    expect(callable.calls, 1);
    expect(appCheck.refreshes, 0);
  });

  test(
    'refreshes once and retries the same request without replacing user',
    () async {
      callable.failures.add('unauthenticated');
      await service.playRace('room', action: 'answer', input: 'KAPI');
      expect(appCheck.refreshes, 1);
      expect(callable.calls, 2);
      expect(callable.requests[0], callable.requests[1]);
      expect(service.currentUserId, 'existing-room-member');
    },
  );

  test('persistent rejection stops after one retry', () async {
    callable.failures.addAll(['unauthenticated', 'unauthenticated']);
    await expectLater(
      service.playRace('room'),
      throwsA(
        isA<RoomServiceException>().having(
          (error) => error.message,
          'message',
          contains('Oturum veya uygulama doğrulanamadı'),
        ),
      ),
    );
    expect(callable.calls, 2);
    expect(appCheck.refreshes, 1);
  });

  test(
    'App Check failure gives actionable error without native details',
    () async {
      callable.failures.add('unauthenticated');
      appCheck.failure = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message: 'sensitive-native-diagnostic',
      );
      await expectLater(
        service.playRace('room'),
        throwsA(
          isA<RoomServiceException>()
              .having((error) => error.code, 'code', 'app-check-failed')
              .having(
                (error) => error.message,
                'message',
                contains('debug tokenını'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('sensitive')),
              ),
        ),
      );
      expect(callable.calls, 1);
    },
  );

  test('empty App Check token does not retry the callable', () async {
    callable.failures.add('unauthenticated');
    appCheck.token = '';
    await expectLater(
      service.playRace('room'),
      throwsA(
        isA<RoomServiceException>().having(
          (error) => error.code,
          'code',
          'app-check-failed',
        ),
      ),
    );
    expect(callable.calls, 1);
  });

  test(
    'other errors are not retried or relabeled as App Check failures',
    () async {
      callable.failures.add('permission-denied');
      await expectLater(
        service.playRace('room'),
        throwsA(
          isA<RoomServiceException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      expect(callable.calls, 1);
      expect(appCheck.refreshes, 0);
    },
  );
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'existing-room-member';
}

class _Database extends Fake implements FirebaseDatabase {}

class _History extends Fake implements QuestionHistoryStore {
  @override
  Future<Map<String, List<String>>> snapshot() async => {
    'completedSetIds': ['completed-set'],
  };
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.callable);
  final _Callable callable;
  final names = <String>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    names.add(name);
    return callable;
  }
}

class _Callable extends Fake implements HttpsCallable {
  final failures = <String>[];
  final requests = <Object?>[];
  int calls = 0;
  Object? result = <String, dynamic>{};

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls++;
    requests.add(parameters);
    if (failures.isNotEmpty) {
      throw FirebaseFunctionsException(
        code: failures.removeAt(0),
        message: 'Callable rejected',
      );
    }
    return _Result<T>(result);
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.value);
  final Object? value;
  @override
  T get data => value as T;
}

class _AppCheck extends Fake implements FirebaseAppCheck {
  int refreshes = 0;
  String? token = 'test-token';
  FirebaseException? failure;

  @override
  Future<String?> getToken([bool? forceRefresh]) async {
    expect(forceRefresh, isTrue);
    refreshes++;
    if (failure != null) throw failure!;
    return token;
  }
}
