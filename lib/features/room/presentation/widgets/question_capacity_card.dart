import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../game/domain/question_capacity.dart';

class QuestionCapacityCard extends StatelessWidget {
  const QuestionCapacityCard({
    required this.capacity,
    this.collective = false,
    super.key,
  });
  final QuestionCapacity capacity;
  final bool collective;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            collective ? 'Ortak havuz uygunluğu' : 'Geçmişine göre soru havuzu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Harf · Toplam / Onaylı / Yayında / Kalan',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final group in capacity.groups)
            Text(
              '${group.length} harf · ${group.total} / ${group.approved} / ${group.published} / ${group.remaining}'
              '${group.blocked ? ' · En az ${group.required} gerekli' : ''}',
              style: TextStyle(
                color: group.blocked ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Teorik üst sınır: ${capacity.upperBoundGames} oyun. '
            'Günde 3 oyunla ${(capacity.upperBoundGames / 3).toStringAsFixed(1)} gün. '
            'Konu, zorluk ve kök sınırları bu sayıyı azaltabilir.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
