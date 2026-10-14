import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../cubit/room_setup_state.dart';
import 'room_setup_page.dart';

class RoomHomePage extends StatelessWidget {
  const RoomHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return NightStudioScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = constraints.maxWidth <= 360 ? 20.0 : 24.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(gutter),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (gutter * 2),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          Text(
                            'CANLI KELİME YARIŞI',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 3,
                                ),
                          ),
                          const SizedBox(height: 24),
                          const Center(child: StudioMark(width: 148)),
                          const SizedBox(height: 24),
                          Text(
                            'Kelime Yarışı',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aynı sorular. Aynı süre. En iyi skor.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () =>
                                _openSetup(context, RoomSetupFlow.create),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Oda Oluştur'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openSetup(context, RoomSetupFlow.join),
                            icon: const Icon(Icons.group_rounded),
                            label: const Text('Odaya Katıl'),
                          ),
                          const SizedBox(height: 24),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                color: AppColors.cyan,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '2–6 oyuncu · Aynı anda canlı oyun',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openSetup(BuildContext context, RoomSetupFlow flow) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => RoomSetupPage(flow: flow)));
  }
}
