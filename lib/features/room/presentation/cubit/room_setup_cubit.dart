import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/firebase_room_service.dart';
import '../../domain/entities/room_game_mode.dart';
import 'room_setup_state.dart';

class RoomSetupCubit extends Cubit<RoomSetupState> {
  RoomSetupCubit(this._roomService, {required RoomSetupFlow flow})
    : super(RoomSetupState(flow: flow));

  final FirebaseRoomService _roomService;

  void displayNameChanged(String value) {
    emit(state.copyWith(displayName: value, clearError: true));
  }

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
    if (!state.canSubmit || state.isSubmitting) {
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
      emit(state.copyWith(room: room, isSubmitting: false, clearError: true));
    } on RoomServiceException catch (error) {
      emit(state.copyWith(isSubmitting: false, errorMessage: error.message));
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Bağlantı kurulamadı. İnternetinizi kontrol edin.',
        ),
      );
    }
  }
}
