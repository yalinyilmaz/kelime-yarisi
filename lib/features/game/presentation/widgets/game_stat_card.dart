import 'package:flutter/material.dart';

import '../../../../core/widgets/studio_components.dart';

class GameStatCard extends StatelessWidget {
  const GameStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioSectionLabel(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    ),
  );
}
