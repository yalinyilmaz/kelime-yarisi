import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_yarisi/core/monitoring/error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('scrubs credentials, player input and request data but preserves crash frames', () {
    final event = SentryEvent.fromJson({
      'event_id': '12345678901234567890123456789012',
      'message': {'formatted': 'secret-message'},
      'user': {'id': 'private-uid', 'email': 'private-email'},
      'request': {'url': 'https://private-url', 'data': 'private-answer'},
      'extra': {'token': 'private-token'},
      'breadcrumbs': [
        {'message': 'private-crumb', 'timestamp': '2026-10-19T00:00:00Z'},
      ],
      'tags': {
        'operation': 'room.start',
        'error_code': 'unauthenticated',
        'roomId': 'private-room',
      },
      'contexts': {
        'device': {'name': 'private-phone', 'model': 'iPhone'},
        'custom': {'input': 'private-input'},
      },
      'exception': {
        'values': [
          {
            'type': 'FirebaseException',
            'value': 'private-native-body',
            'stacktrace': {
              'frames': [
                {
                  'filename': 'game.dart',
                  'function': 'start',
                  'lineno': 12,
                  'vars': {'answer': 'private-answer'},
                  'context_line': 'private-source',
                },
              ],
            },
            'mechanism': {'type': 'generic', 'handled': false},
          },
        ],
      },
    });
    final safe = sanitizeSentryEvent(event, Hint());
    final encoded = jsonEncode(safe.toJson());
    expect(encoded, isNot(contains('private-')));
    expect(encoded, isNot(contains('secret-message')));
    expect(safe.exceptions!.single.type, 'FirebaseException');
    expect(safe.exceptions!.single.value, 'unauthenticated');
    expect(safe.exceptions!.single.stackTrace!.frames.single.lineNo, 12);
    expect(safe.exceptions!.single.mechanism!.handled, false);
  });

  test(
    'handled Firebase error arrives once, without its original message',
    () async {
      final transport = _RecordingTransport();
      await Sentry.init((options) {
        options.dsn = 'https://12345678901234567890123456789012@localhost/1';
        options.transport = transport;
        options.beforeSend = sanitizeSentryEvent;
        options.enableLogs = false;
        options.enableMetrics = false;
      });
      try {
        final error = FirebaseException(
          plugin: 'firebase',
          code: 'permission-denied',
          message: 'do-not-send-this-token',
        );
        ErrorReporter.report(
          error,
          StackTrace.current,
          operation: 'test.handled',
        );
        ErrorReporter.report(
          error,
          StackTrace.current,
          operation: 'test.handled',
        );
        await transport.received.future.timeout(const Duration(seconds: 5));
        expect(transport.events, hasLength(1));
        expect(transport.events.single, contains('permission-denied'));
        expect(transport.events.single, contains('FirebaseException'));
        expect(
          transport.events.single,
          isNot(contains('do-not-send-this-token')),
        );
        expect(transport.events.single, contains('error_reporter_test.dart'));
      } finally {
        await Sentry.close();
      }
    },
  );
}

class _RecordingTransport implements Transport {
  final List<String> events = [];
  final received = Completer<void>();
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    for (final item in envelope.items) {
      if (item.header.type == 'event') {
        events.add(utf8.decode(await item.dataFactory()));
      }
    }
    if (events.isNotEmpty && !received.isCompleted) received.complete();
    return envelope.header.eventId;
  }
}
