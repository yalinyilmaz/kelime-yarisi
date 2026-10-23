import '../../../../core/monitoring/error_reporter.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/firebase_room_service.dart';
import '../../domain/entities/room_game_mode.dart';
import 'room_setup_state.dart';

class RoomSetupCubit extends Cubit<RoomSetupState> {
  RoomSetupCubit(
    this._roomService, {
    required RoomSetupFlow flow,
    required String displayName,
    String initialRoomCode = '',
  }) : super(
         RoomSetupState(
           flow: flow,
           displayName: displayName,
           roomCode: initialRoomCode,
           roomName: flow == RoomSetupFlow.create ? "$displayName's Room" : '',
         ),
       );

  final FirebaseRoomService _roomService;

  void roomNameChanged(String value) {
    emit(state.copyWith(roomName: value, clearError: true));
  }

  void roomCodeChanged(String value) {
    emit(
      state.copyWith(
        roomCode: value.toUpperCase().replaceAll(' ', ''),
        clearError: true,
      ),
    );
  }

  void playerCountChanged(int value) {
    emit(state.copyWith(targetPlayerCount: value, clearError: true));
  }

  Future<void> submit() async {
    if (isClosed || state.isSubmitting || state.room != null) return;
    if (!state.canSubmit) {
      emit(
        state.copyWith(errorMessage: 'Alanları kontrol edip tekrar deneyin.'),
      );
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final room = switch (state.flow) {
        RoomSetupFlow.create => await _roomService.createRoom(
          displayName: state.displayName,
          roomName: state.roomName,
          targetPlayerCount: state.targetPlayerCount,
          gameMode: RoomGameMode.classic,
        ),
        RoomSetupFlow.join => await _roomService.joinRoom(
          displayName: state.displayName,
          roomCode: state.roomCode,
        ),
      };
      if (isClosed) {
        // The user left while create/join was pending; do not leave an orphan room/presence.
        await _roomService.leaveRoom(room.id);
        return;
      }
      emit(state.copyWith(room: room, isSubmitting: false, clearError: true));
    } on RoomServiceException catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'room_setup_cubit.submit',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.message,
          errorCode: error.code,
        ),
      );
    } catch (error, stackTrace) {
      ErrorReporter.report(
        error,
        stackTrace,
        operation: 'room_setup_cubit.submit',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Bağlantı kurulamadı. İnternetinizi kontrol edin.',
          errorCode: 'connection-failed',
        ),
      );
    }
  }
}
