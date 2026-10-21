import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Service failures expose a stable code, never request/response contents.
abstract interface class DiagnosticFailure {
  String get code;
}

abstract final class ErrorReporter {
  static final Expando<bool> _reported = Expando<bool>();
  static final Map<String, DateTime> _recent = {};

  static void report(
    Object error,
    StackTrace stack, {
    required String operation,
  }) {
    // The same failure may cross service, stream and Cubit boundaries.
    if (error is! String && error is! num && error is! bool) {
      if (_reported[error] == true) return;
      _reported[error] = true;
    }
    final code = switch (error) {
      FirebaseException e => e.code,
      PlatformException e => e.code,
      DiagnosticFailure e => e.code,
      _ => null,
    };
    final safeCode =
        code != null && RegExp(r'^[a-zA-Z0-9_/-]{1,80}$').hasMatch(code)
        ? code
        : null;
    final type = error.runtimeType.toString();
    final key = '$operation:$type:$safeCode';
    final now = DateTime.now();
    _recent.removeWhere(
      (_, time) => now.difference(time) >= const Duration(minutes: 1),
    );
    if (_recent.containsKey(key)) return;
    if (_recent.length >= 100) _recent.remove(_recent.keys.first);
    _recent[key] = now;
    unawaited(_capture(type, safeCode, stack, operation));
  }

  static Future<void> _capture(
    String type,
    String? code,
    StackTrace stack,
    String operation,
  ) async {
    try {
      await Sentry.captureException(
        _ReportedFailure(type, code),
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('operation', operation);
          scope.setTag('component', 'flutter');
          scope.setTag('error_type', type);
          if (code != null) scope.setTag('error_code', code);
        },
      );
    } catch (_) {
      // Monitoring must never interrupt a game or recursively report itself.
    }
  }
}

class ErrorReportingBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    ErrorReporter.report(
      error,
      stackTrace,
      operation: '${bloc.runtimeType}.onError',
    );
    super.onError(bloc, error, stackTrace);
  }
}

/// Preserve stack addresses/symbols, discard arbitrary payloads and credentials.
SentryEvent sanitizeSentryEvent(SentryEvent event, Hint hint) {
  final json = event.toJson();
  for (final key in [
    'user',
    'request',
    'extra',
    'breadcrumbs',
    'transaction',
    'server_name',
    'logentry',
  ]) {
    json.remove(key);
  }
  final tags = event.tags ?? const <String, String>{};
  json['tags'] = {
    for (final key in [
      'operation',
      'component',
      'error_code',
      'error_type',
      'build_mode',
    ])
      if (tags.containsKey(key)) key: tags[key],
  };
  final exceptions = json['exception'];
  if (exceptions is Map && exceptions['values'] is List) {
    for (final exception in exceptions['values'] as List) {
      if (exception is Map) {
        if (tags['error_type'] != null) exception['type'] = tags['error_type'];
        final mechanism = exception['mechanism'];
        if (mechanism is Map) mechanism.remove('data');
        exception['value'] =
            tags['error_code'] ??
            'Details omitted; inspect type and stack trace';
      }
    }
  }
  void scrubFrames(dynamic node) {
    if (node is Map) {
      for (final key in [
        'vars',
        'pre_context',
        'post_context',
        'context_line',
      ]) {
        node.remove(key);
      }
      for (final value in node.values) {
        scrubFrames(value);
      }
    } else if (node is List) {
      for (final value in node) {
        scrubFrames(value);
      }
    }
  }

  scrubFrames(json['exception']);
  scrubFrames(json['threads']);
  final contexts = json['contexts'];
  if (contexts is Map) {
    contexts.removeWhere(
      (key, _) => !['app', 'os', 'device', 'runtime', 'trace'].contains(key),
    );
    final device = contexts['device'];
    if (device is Map) {
      for (final key in ['name', 'id', 'device_unique_identifier']) {
        device.remove(key);
      }
    }
  }
  // Messages from the explicit reporter contain only type/code. Framework
  // messages can contain user input or native Firebase response bodies.
  json.remove('message');
  return SentryEvent.fromJson(json);
}

Future<void> initializeErrorReporting(AppRunner appRunner) async {
  const dsn = String.fromEnvironment('SENTRY_DSN');
  final environment = appFlavor == 'prod' ? 'prod' : 'dev';
  if (dsn.isEmpty) {
    debugPrint('Sentry yapılandırılmamış: SENTRY_DSN eksik.');
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    options
      ..dsn = dsn
      ..environment = environment
      ..sendDefaultPii = false
      ..sampleRate = 1
      ..tracesSampleRate = 0
      ..enableLogs = false
      ..enableMetrics = false
      ..enablePrintBreadcrumbs = false
      ..enableAutoNativeBreadcrumbs = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableAutoPerformanceTracing = false
      ..attachScreenshot = false
      ..beforeBreadcrumb = ((_, _) => null)
      ..beforeSend = sanitizeSentryEvent;
    options.replay.sessionSampleRate = 0;
    options.replay.onErrorSampleRate = 0;
    const release = String.fromEnvironment('SENTRY_RELEASE');
    const dist = String.fromEnvironment('SENTRY_DIST');
    const proguardUuid = String.fromEnvironment('SENTRY_PROGUARD_UUID');
    if (release.isNotEmpty) options.release = release;
    if (dist.isNotEmpty) options.dist = dist;
    if (defaultTargetPlatform == TargetPlatform.android &&
        proguardUuid.isNotEmpty) {
      options.proguardUuid = proguardUuid;
    }
    options.beforeSend = (event, hint) {
      event.tags = {
        ...?event.tags,
        'component': 'flutter',
        'build_mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
      };
      return sanitizeSentryEvent(event, hint);
    };
  }, appRunner: appRunner);
}

class _ReportedFailure implements Exception {
  const _ReportedFailure(this.type, this.code);
  final String type;
  final String? code;
  @override
  String toString() => '$type${code == null ? '' : ': $code'}';
}
