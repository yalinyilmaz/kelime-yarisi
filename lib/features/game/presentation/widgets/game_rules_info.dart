import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class GameRulesInfo extends StatelessWidget {
  const GameRulesInfo({this.requiredHintVotes, this.isRace = true, super.key});

  final int? requiredHintVotes;
  final bool isRace;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.cyan),
      const SizedBox(width: 8),
      Expanded(
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                requiredHintVotes == null
                    ? '2–3 oyuncuda bir oy, 4–6 oyuncuda iki farklı oyuncunun oyuyla aynı harf herkeste açılır. Her harf soru değerini 100 azaltır.'
                    : '$requiredHintVotes farklı oyuncunun oyuyla aynı harf herkeste açılır. Her harf soru değerini 100 azaltır.',
              ),
              Text(
                isRace
                    ? 'İlk doğru cevap soruyu kapatır ve puanı kazanır. Yanlış cevap, süre aşımı veya başka oyuncunun bilmesi puan kaybettirmez. Yanlış cevap veren oyuncu sonraki soruyu bekler.'
                    : 'Doğru cevap: +soru değeri. Yanlış cevap veya süre aşımı puan kaybettirmez. '
                          'Cevap sonrası sorunun bitmesi beklenir. Süre dolunca cevapsız soru bilememiş sayılır. Pas yok.',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
