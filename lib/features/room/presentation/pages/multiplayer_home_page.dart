import '../widgets/multiplayer_mode_card.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
                MultiplayerModeCard(
                  title: 'Diğer oyuncularla yarış',
                  description: '2–6 oyuncu aynı soruyu aynı anda görür. Ortak süre içinde sesli yanıt ver; ilk doğru cevabı söyleyen puanı kazanır.',
                  icon: Icons.groups_rounded,
                  selected: true,
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                const MultiplayerModeCard(
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
