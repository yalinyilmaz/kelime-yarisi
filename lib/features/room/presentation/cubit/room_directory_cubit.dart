import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/monitoring/error_reporter.dart';
import '../../data/firebase_room_service.dart';
import '../../domain/entities/game_room.dart';
import '../../domain/entities/room_listing.dart';

class RoomDirectoryState extends Equatable {
  const RoomDirectoryState({
    this.rooms = const [],
    this.loading = true,
    this.joiningId,
    this.submitting = false,
    this.error,
  });
  final List<RoomListing> rooms;
  final bool loading;
  final String? joiningId;
  final bool submitting;
  final String? error;
  bool get joining => joiningId != null;

  RoomDirectoryState copyWith({
    List<RoomListing>? rooms,
    bool? loading,
    String? joiningId,
    bool? submitting,
    String? error,
    bool clearError = false,
    bool clearJoin = false,
  }) => RoomDirectoryState(
    rooms: rooms ?? this.rooms,
    loading: loading ?? this.loading,
    joiningId: clearJoin ? null : joiningId ?? this.joiningId,
    submitting: submitting ?? this.submitting,
    error: clearError ? null : error ?? this.error,
  );
  @override
  List<Object?> get props => [rooms, loading, joiningId, submitting, error];
}

class RoomDirectoryCubit extends Cubit<RoomDirectoryState> {
  RoomDirectoryCubit(this._service) : super(const RoomDirectoryState());
  final FirebaseRoomService _service;
  bool _loading = false;
  int _joinEpoch = 0;

  Future<void> load() async {
    if (isClosed || _loading || state.joining) return;
    _loading = true;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final rooms = await _service.listRooms();
      if (!isClosed) emit(state.copyWith(rooms: rooms, loading: false));
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'room_directory.list');
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: _message(error)));
      }
    } finally {
      _loading = false;
    }
  }

  bool beginJoin(RoomListing listing) {
    if (isClosed || state.joining || listing.isFull) return false;
    ++_joinEpoch;
    emit(state.copyWith(joiningId: listing.id, clearError: true));
    return true;
  }

  void finishJoin({bool clearError = true}) {
    ++_joinEpoch;
    if (!isClosed) {
      emit(
        state.copyWith(
          clearJoin: true,
          submitting: false,
          clearError: clearError,
        ),
      );
    }
  }

  void clearError() {
    if (!isClosed && state.error != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  Future<GameRoom?> join(
    RoomListing listing,
    String displayName, {
    String? roomCode,
  }) async {
    if (isClosed || state.submitting || state.joiningId != listing.id) {
      return null;
    }
    final epoch = _joinEpoch;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final room = await _service.joinListedRoom(
        directoryId: listing.id,
        displayName: displayName,
        roomCode: roomCode,
      );
      if (isClosed || epoch != _joinEpoch) {
        await releaseJoinedRoom(room);
        return null;
      }
      return room;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'room_directory.join');
      if (!isClosed && epoch == _joinEpoch) {
        emit(state.copyWith(submitting: false, error: _message(error)));
      }
      return null;
    }
  }

  Future<void> releaseJoinedRoom(GameRoom room) async {
    try {
      await _service.leaveRoom(room.id);
    } catch (error, stack) {
      ErrorReporter.report(
        error,
        stack,
        operation: 'room_directory.abandoned_join',
      );
    }
  }

  String _message(Object error) => error is RoomServiceException
      ? error.message
      : 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.';
}
