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
                ? 'Oda sahibi çıkarsa oda herkes için kapanır.'
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

  static Future<bool> giveUp(
    BuildContext context, {
    required int points,
    bool advanceImmediately = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bilemiyorum'),
          content: Text(
            advanceImmediately
                ? '$points puan kaybedip sonraki soruya geçeceksin.'
                : '$points puan kaybedip bu sorunun bitmesini bekleyeceksin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Devam et'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bilemiyorum'),
            ),
          ],
        ),
      ) ??
      false;
}
