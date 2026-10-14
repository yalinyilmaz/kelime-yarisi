import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../features/room/data/firebase_room_service.dart';
import '../features/room/presentation/pages/room_home_page.dart';

class KelimeYarisiApp extends StatelessWidget {
  const KelimeYarisiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => FirebaseRoomService(),
      child: MaterialApp(
        title: 'Kelime Yarışı',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const RoomHomePage(),
      ),
    );
  }
}
