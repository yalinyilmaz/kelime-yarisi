import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/studio_components.dart';

class MultiplayerHomePage extends StatelessWidget {
  const MultiplayerHomePage({super.key});

  @override
  Widget build(BuildContext context) => NightStudioScaffold(
    appBar: AppBar(title: const Text('Çok Oyunculu')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.groups_rounded, size: 64),
                const SizedBox(height: 20),
                Text(
                  'Arkadaşlarınla yarış',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  '2–6 oyuncu · Aynı sorular, ortak süre.\nİlk doğru cevap puanı kazanır.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.go('/create'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Oda Oluştur'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/join'),
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Odaya Katıl'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
