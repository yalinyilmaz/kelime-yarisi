import '../core/monitoring/error_reporter.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/theme/app_theme.dart';
import '../core/speech/speech_input_cubit.dart';
import '../features/room/data/firebase_room_service.dart';
import '../features/solo/presentation/cubit/solo_best_score_cubit.dart';
import 'app_router.dart';

class KelimeYarisiApp extends StatefulWidget {
  const KelimeYarisiApp({
    super.key,
    this.roomService,
    this.soloScoreStorage,
    this.speechRecognizer,
  });

  final FirebaseRoomService? roomService;
  final Storage? soloScoreStorage;
  final SpeechToText? speechRecognizer;

  @override
  State<KelimeYarisiApp> createState() => _KelimeYarisiAppState();
}

class _KelimeYarisiAppState extends State<KelimeYarisiApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    final storage = widget.soloScoreStorage;
    if (storage != null) {
      unawaited(
        storage.close().catchError((Object error, StackTrace stackTrace) {
          ErrorReporter.report(error, stackTrace, operation: 'app.dispose');
          debugPrint('Skor depolaması kapatılamadı.');
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => widget.roomService ?? FirebaseRoomService(),
      dispose: (service) => unawaited(
        service.dispose().catchError((Object error, StackTrace stackTrace) {
          ErrorReporter.report(error, stackTrace, operation: 'app.dispose');
          debugPrint('Uygulama kaynakları kapatılamadı.');
        }),
      ),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => SoloBestScoreCubit(storage: widget.soloScoreStorage),
          ),
          BlocProvider(
            create: (_) =>
                SpeechInputCubit(recognizer: widget.speechRecognizer),
          ),
        ],
        child: MaterialApp.router(
          title: 'Kelime Yarışı',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          routerConfig: _router,
        ),
      ),
    );
  }
}
