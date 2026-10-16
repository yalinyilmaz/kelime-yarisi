import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/room/data/firebase_room_service.dart';
import 'app_router.dart';

class KelimeYarisiApp extends StatefulWidget {
  const KelimeYarisiApp({super.key, this.roomService});

  final FirebaseRoomService? roomService;

  @override
  State<KelimeYarisiApp> createState() => _KelimeYarisiAppState();
}

class _KelimeYarisiAppState extends State<KelimeYarisiApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => widget.roomService ?? FirebaseRoomService(),
      child: MaterialApp.router(
        title: 'Kelime Yarışı',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}
