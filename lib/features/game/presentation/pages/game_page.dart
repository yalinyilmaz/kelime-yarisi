import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../room/data/firebase_room_service.dart';
import '../../../room/domain/entities/game_room.dart';
import '../../domain/game_progress.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';

class GamePage extends StatelessWidget {
  const GamePage({required this.room, super.key});

  final GameRoom room;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GameCubit(context.read<FirebaseRoomService>(), room),
    child: const _GameView(),
  );
}

class _GameView extends StatefulWidget {
  const _GameView();

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  final _answer = TextEditingController();

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final cubit = context.read<GameCubit>();
    final isHost =
        cubit.state.room.hostId ==
        context.read<FirebaseRoomService>().currentUserId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odadan çıkılsın mı?'),
        content: Text(
          isHost
              ? 'Oda sahibi çıkarsa oda herkes için kapanır.'
              : 'Bu yarışmadan ayrılacaksın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await cubit.leaveRoom();
    if (mounted && cubit.state.isLeaving) Navigator.of(context).pop();
  }

  Future<void> _giveUp() async {
    final cubit = context.read<GameCubit>();
    final index = cubit.state.progress.questionIndex;
    final value = cubit.state.question == null
        ? 0
        : cubit.state.progress.valueFor(cubit.state.question!);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bilemiyorum'),
        content: Text('$value puan kaybedip sonraki soruya geçeceksin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Devam et'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bilemiyorum'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        cubit.state.progress.questionIndex == index) {
      await cubit.giveUp();
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<GameCubit, GameState>(
    listenWhen: (before, after) =>
        before.progress.questionIndex != after.progress.questionIndex,
    listener: (_, _) => _answer.clear(),
    builder: (context, state) {
      final question = state.question;
      final isResults = state.room.status == RoomStatus.results;
      final seconds = state.remainingSeconds;
      final time =
          '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      return PopScope(
        canPop: state.isLeaving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: NightStudioScaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Odadan çık',
              onPressed: state.isLeaving ? null : _leave,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(isResults ? 'Yarışma tamamlandı' : state.room.name),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            label: 'PUANIN',
                            value: '${state.progress.score}',
                            color: AppColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Stat(
                            label: 'KALAN SÜRE',
                            value: state.clockReady ? time : '—',
                            color: seconds <= 30
                                ? AppColors.warning
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!state.isConnected)
                      const _Notice(
                        'Bağlantı bekleniyor. Ortak süre devam ediyor.',
                      ),
                    if (state.errorMessage != null)
                      _Notice(state.errorMessage!, error: true),
                    if (state.feedback != null)
                      Semantics(
                        liveRegion: true,
                        child: _Notice(state.feedback!),
                      ),
                    if (state.questions.isEmpty)
                      const _Notice(
                        'Bu oyun açılamadı. Uygulamayı güncelleyip yeni bir oda oluştur.',
                      ),
                    if (question != null &&
                        !state.hasExpired &&
                        !isResults) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StudioSectionLabel(
                                'SORU ${state.progress.questionIndex + 1} / ${state.questions.length}',
                              ),
                              const SizedBox(height: 12),
                              Text(
                                question.clue,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 24),
                              Semantics(
                                label: '${question.letterCount} harfli kelime',
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 8,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < question.letterCount;
                                      i++
                                    )
                                      Container(
                                        width: 32,
                                        height: 42,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: state.progress.isRevealed(i)
                                              ? AppColors.paper
                                              : AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          state.progress.isRevealed(i)
                                              ? question.answer[i]
                                              : '·',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: state.progress.isRevealed(i)
                                                ? AppColors.onPaper
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Soru değeri: ${state.progress.valueFor(question)} puan',
                                style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _answer,
                        enabled: state.canAct,
                        maxLength: 24,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Cevabın',
                          counterText: '',
                        ),
                        onSubmitted: state.canAct
                            ? context.read<GameCubit>().submitAnswer
                            : null,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: state.canAct
                            ? () => context.read<GameCubit>().submitAnswer(
                                _answer.text,
                              )
                            : null,
                        icon: state.isSaving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: const Text('Cevapla'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            state.canAct &&
                                state.progress.valueFor(question) > 100
                            ? context.read<GameCubit>().revealLetter
                            : null,
                        icon: const Icon(Icons.lightbulb_outline_rounded),
                        label: const Text('Harf Al · −100 soru değeri'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: state.canAct ? _giveUp : null,
                        child: const Text('Bilemiyorum · Puan kaybet'),
                      ),
                      const Text(
                        'Doğru cevap: +soru değeri. Yanlış cevap veya bilemiyorum: −soru değeri. '
                        'Süre dolunca açık soru bilememiş sayılır. Pas yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ] else if (state.questions.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.flag_rounded,
                                size: 40,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                state.hasExpired
                                    ? 'Süre doldu'
                                    : 'Soruları tamamladın',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${state.progress.correctCount} doğru · ${state.progress.wrongCount} bilemedin',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.progress.finished
                                    ? isResults
                                          ? 'Yarışmanın puanları aşağıda.'
                                          : 'Diğer oyuncular oynuyor. Süre sonunda sonuçlar açıklanacak.'
                                    : 'Sonucun Firebase’e kaydediliyor…',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    StudioSectionLabel(
                      isResults ? 'SONUÇLAR' : 'CANLI PUANLAR',
                    ),
                    const SizedBox(height: 8),
                    _Scores(state: state),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
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

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false});
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

class _Scores extends StatelessWidget {
  const _Scores({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<FirebaseRoomService>().currentUserId;
    GameProgress progressFor(String id) => id == uid
        ? state.progress
        : state.room.progress[id] ?? const GameProgress();
    final players = [...state.room.players]
      ..sort((a, b) {
        final scoreOrder = progressFor(b.id).score
            .compareTo(progressFor(a.id).score);
        return scoreOrder != 0 ? scoreOrder : a.id.compareTo(b.id);
      });
    return Column(
      children: [
        for (var i = 0; i < players.length; i++)
          Card(
            child: ListTile(
              leading: Text(
                '${1 + players.where((p) => progressFor(p.id).score > progressFor(players[i].id).score).length}',
              ),
              title: Text(
                '${players[i].displayName}${players[i].id == uid ? ' (Sen)' : ''}',
              ),
              subtitle: Text(
                !players[i].isOnline
                    ? 'Çevrimdışı'
                    : progressFor(players[i].id).finished
                    ? 'Tamamlandı'
                    : state.hasExpired
                    ? 'Sonuç bekleniyor'
                    : '${progressFor(players[i].id).questionIndex} soru tamamlandı',
              ),
              trailing: Text(
                '${progressFor(players[i].id).score}',
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
