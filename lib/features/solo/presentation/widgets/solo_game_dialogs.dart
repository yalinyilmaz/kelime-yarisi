import 'package:flutter/material.dart';

abstract final class SoloGameDialogs {
  static Future<bool> leave(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Oyundan çıkılsın mı?'),
          content: const Text(
            'Oyunu şimdi terk edersen puanın sayılmayacak ve kişisel rekoruna eklenmeyecek. Bu sete daha sonra yeniden denk gelebilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Oyuna Dön'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oyunu Terk Et'),
            ),
          ],
        ),
      ) ??
      false;
}
