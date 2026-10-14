import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../room/data/firebase_room_service.dart';
import '../../../room/domain/entities/game_room.dart';
import '../../domain/game_progress.dart';
import '../audio/game_sound_controller.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';
import '../widgets/word_pin_input.dart';

class GamePage extends StatelessWidget {
  const GamePage({required this.room, this.sounds, super.key});

  final GameRoom room;
  final GameSoundController? sounds;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GameCubit(context.read<FirebaseRoomService>(), room),
    child: _GameView(sounds: sounds),
  );
}

class _GameView extends StatefulWidget {
  const _GameView({this.sounds});

  final GameSoundController? sounds;

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> with WidgetsBindingObserver {
  final _answer = TextEditingController();
  late final GameSoundController _sounds;

  @override
  void initState() {
    super.initState();
    _sounds = widget.sounds ?? GameSoundController();
    WidgetsBinding.instance.addObserver(this);
    final state = context.read<GameCubit>().state;
    _sounds.update(state);
    unawaited(_sounds.initialize());
    unawaited(
      _sounds.setForeground(
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_sounds.setForeground(state == AppLifecycleState.resumed));
  }

  Future<void> _submit() async {
    final cubit = context.read<GameCubit>();
    if (!cubit.state.canAct) return;
    if (_answer.text.length != cubit.state.question!.letterCount) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Tüm boş harfleri doldur.')),
        );
      return;
    }
    final index = cubit.state.questionIndex;
    await cubit.submitAnswer(_answer.text);
    if (mounted &&
        cubit.state.questionIndex == index &&
        cubit.state.hasAnsweredCurrent) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sounds.dispose());
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
    final index = cubit.state.questionIndex;
    final value = cubit.state.questionValue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bilemiyorum'),
        content: Text(
          '$value puan kaybedip bu sorunun bitmesini bekleyeceksin.',
        ),
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
    if (confirmed == true && mounted && cubit.state.questionIndex == index) {
      await cubit.giveUp();
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<GameCubit, GameState>(
    listener: (_, state) => _sounds.update(state),
    child: BlocSelector<GameCubit, GameState, _ViewSelection>(
      selector: (state) => (
        room: state.room,
        progress: state.progress,
        questionIndex: state.questionIndex,
        canAct: state.canAct,
        canEditAnswer: state.canEditAnswer,
        hasExpired: state.hasExpired,
        isConnected: state.isConnected,
        isLeaving: state.isLeaving,
        isSaving: state.isSaving,
        isVoting: state.isVoting,
        feedback: state.feedback,
        errorMessage: state.errorMessage,
      ),
      builder: (context, _) {
        final state = context.read<GameCubit>().state;
        final question = state.question;
        final isResults = state.room.status == RoomStatus.results;
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
              actions: [
                IconButton(
                  tooltip: _sounds.enabled ? 'Sesi kapat' : 'Sesi aç',
                  onPressed: () {
                    setState(() {
                      unawaited(_sounds.setEnabled(!_sounds.enabled));
                    });
                  },
                  icon: Icon(
                    _sounds.enabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
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
                                const Expanded(child: _QuestionClock()),
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
                                key: const ValueKey('question-card'),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      StudioSectionLabel(
                                        'SORU ${state.questionIndex + 1} / ${state.questions.length}',
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        question.clue,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(height: 24),
                                      WordPinInput(
                                        question: question,
                                        questionIndex: state.questionIndex,
                                        revealedMask: state.hints.revealedMask(
                                          state.room.id,
                                          state.questionIndex,
                                          question.letterCount,
                                        ),
                                        enabled: state.canEditAnswer,
                                        answerController: _answer,
                                        onSubmitted: _submit,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Soru değeri: ${state.questionValue} puan',
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
                              if (state.hasAnsweredCurrent)
                                const _Notice(
                                  'Cevabın kaydedildi. Süre bitince herkes aynı anda sonraki soruya geçecek.',
                                ),
                              Text(
                                '${state.room.requiredHintVotes} farklı oyuncunun oyuyla aynı harf herkeste açılır. '
                                'Her harf soru değerini 100 azaltır.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: state.canAct ? _giveUp : null,
                                child: const Text('Bilemiyorum · Puan kaybet'),
                              ),
                              const Text(
                                'Doğru cevap: +soru değeri. Yanlış cevap veya bilemiyorum: −soru değeri. '
                                'Cevap sonrası sorunun bitmesi beklenir. Süre dolunca cevapsız soru bilememiş sayılır. Pas yok.',
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
                      if (question != null && !state.hasExpired && !isResults)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: _GameActions(state: state, onSubmit: _submit),
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
  );
}

class _GameActions extends StatelessWidget {
  const _GameActions({required this.state, required this.onSubmit});

  final GameState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          key: const ValueKey('answer-action'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: state.canAct ? onSubmit : null,
          icon: state.isSaving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: const Text('Cevapla'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('hint-action'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: state.canVote
              ? context.read<GameCubit>().revealLetter
              : null,
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Harf Al'),
              Text(
                state.isVoting
                    ? 'Kaydediliyor…'
                    : state.hasVoted
                    ? 'Oy verdin · 1/${state.room.requiredHintVotes}'
                    : '${state.hints.firstVoterId == null ? 0 : 1}/${state.room.requiredHintVotes} oy',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

typedef _ViewSelection = ({
  GameRoom room,
  GameProgress progress,
  int questionIndex,
  bool canAct,
  bool canEditAnswer,
  bool hasExpired,
  bool isConnected,
  bool isLeaving,
  bool isSaving,
  bool isVoting,
  String? feedback,
  String? errorMessage,
});

class _QuestionClock extends StatelessWidget {
  const _QuestionClock();

  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<GameCubit, GameState, (bool, int)>(
    selector: (state) => (state.clockReady, state.remainingSeconds),
    builder: (context, clock) => _Stat(
      label: 'SORU SÜRESİ',
      value: clock.$1
          ? '${clock.$2 ~/ 60}:${(clock.$2 % 60).toString().padLeft(2, '0')}'
          : '—',
      color: clock.$2 <= 5 ? AppColors.warning : AppColors.textPrimary,
    ),
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
