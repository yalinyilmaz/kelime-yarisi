import 'leave_room_dialog.dart';

import 'package:flutter/material.dart';

abstract final class GameConfirmationDialogs {
  static Future<bool> leave(
    BuildContext context, {
    required bool isHost,
    required Future<String?> Function() onLeave,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LeaveRoomDialog(isHost: isHost, onLeave: onLeave),
      ) ??
      false;
}
