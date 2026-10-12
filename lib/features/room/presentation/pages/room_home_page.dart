import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/room_setup_state.dart';
import 'room_setup_page.dart';

class RoomHomePage extends StatelessWidget {
  const RoomHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Align(
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332367D1),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Text(
                    'K',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Kelime Yarışı',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Aynı soru seti, aynı süre, herkes için ayrı bir yarış.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openSetup(context, RoomSetupFlow.create),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Oda Oluştur'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openSetup(context, RoomSetupFlow.join),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: const BorderSide(color: AppColors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Odaya Katıl'),
              ),
              const SizedBox(height: 20),
              const Text(
                '2–5 oyuncu · Aynı anda canlı oyun',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
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
