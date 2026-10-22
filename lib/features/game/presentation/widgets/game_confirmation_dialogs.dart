import 'package:flutter/material.dart';

abstract final class GameConfirmationDialogs {
  static Future<bool> leave(
    BuildContext context, {
    required bool isHost,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Odadan çıkılsın mı?'),
          content: Text(
            isHost
                ? 'Yarışmadan ayrılacaksın. Başka oyuncu varsa oda sahipliği devredilir; son oyuncuysan oda kapanır.'
                : 'Bu yarışmadan ayrılacaksın.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Çık'),
            ),
          ],
        ),
      ) ??
      false;
}
