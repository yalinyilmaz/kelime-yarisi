import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/firebase_room_service.dart';
import '../cubit/room_directory_cubit.dart';
import '../widgets/room_directory_view.dart';

class RoomDirectoryPage extends StatelessWidget {
  const RoomDirectoryPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        RoomDirectoryCubit(context.read<FirebaseRoomService>())..load(),
    child: const RoomDirectoryView(),
  );
}
