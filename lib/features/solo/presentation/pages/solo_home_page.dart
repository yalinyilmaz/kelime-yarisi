import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../cubit/solo_best_score_cubit.dart';

class SoloHomePage extends StatelessWidget {
  const SoloHomePage({super.key});

  @override
  Widget build(BuildContext context) => NightStudioScaffold(
    appBar: AppBar(title: const Text('Tek Oyunculu')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.warning,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  'Kendi rekorunu kır',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const StudioSectionLabel('KİŞİSEL REKOR'),
                        const SizedBox(height: 8),
                        BlocSelector<SoloBestScoreCubit, int?, int?>(
                          selector: (score) => score,
                          builder: (context, score) => Text(
                            '${score ?? '—'} / 9.800',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(color: AppColors.cyan),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '14 soru · Toplam 4 dakika 20 saniye',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Her harf, soru değerini 100 puan azaltır. Oyun boyunca 10 ipucu hakkın var; her soruda en fazla 2 ipucu kullanabilirsin.\n\nRekorun, 14 soruyu tamamladığında kaydedilir.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const ValueKey('solo-start'),
                  onPressed: () => context.go('/solo/play'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Başla'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
