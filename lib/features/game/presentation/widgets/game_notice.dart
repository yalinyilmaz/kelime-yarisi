import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class GameNotice extends StatelessWidget {
  const GameNotice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: error ? AppColors.warning : AppColors.textSecondary,
      ),
    ),
  );
}
