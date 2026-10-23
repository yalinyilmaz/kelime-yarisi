import 'package:flutter/material.dart';
import 'package:kelime_yarisi/core/theme/app_colors.dart';

abstract final class SoloGameDialogs {
  static Future<bool> leave(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceMuted,
          title: const Text('Oyundan çıkılsın mı?'),
          content: const Text(
            'Oyunu şimdi terk edersen puanın sayılmayacak ve kişisel rekoruna eklenmeyecek. Bu sete daha sonra yeniden denk gelebilirsin.',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Oyuna Dön'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Oyunu Terk Et'),
            ),
          ],
        ),
      ) ??
      false;
}
