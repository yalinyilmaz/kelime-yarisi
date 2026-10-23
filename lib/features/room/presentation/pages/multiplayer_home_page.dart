import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';

class MultiplayerHomePage extends StatelessWidget {
  const MultiplayerHomePage({super.key});

  @override
  Widget build(BuildContext context) => NightStudioScaffold(
    appBar: AppBar(title: const Text('Çok Oyunculu')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModeCard(
                  title: 'Diğer oyuncularla yarış',
                  description: '2–6 oyuncu aynı soruyu aynı anda görür. Ortak süre içinde sesli yanıt ver; ilk doğru cevabı söyleyen puanı kazanır.',
                  icon: Icons.groups_rounded,
                  selected: true,
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                const _ModeCard(
                  title: 'Hızlı Mod',
                  description: '7 soru, sesli yanıt. Diğer oyuncularla ve süreyle yarış; en yüksek puanı en kısa sürede toplamayı hedefle.',
                  icon: Icons.bolt_rounded,
                  selected: false,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/multiplayer/rooms'),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Devam'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    enabled: onTap != null,
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outline,
          width: selected ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: selected ? AppColors.cyan : AppColors.textSecondary,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                    )
                  else
                    const Text(
                      'Yakında',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
