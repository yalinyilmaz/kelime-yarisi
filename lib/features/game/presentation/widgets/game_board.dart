import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../room/domain/entities/game_room.dart';
import '../cubit/game_state.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/game_cubit.dart';
import 'game_answer_actions.dart';
import 'game_notice.dart';
import 'game_current_question.dart';
import 'game_live_score.dart';
import 'game_standings.dart';
import 'previous_answer_feedback.dart';
import 'question_clock.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({
    required this.answerController,
    required this.onSubmit,
    super.key,
  });
  final TextEditingController answerController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => BlocBuilder<GameCubit, GameState>(
    buildWhen: (a, b) =>
        a.questionIndex != b.questionIndex ||
        a.question != b.question ||
        a.hasExpired != b.hasExpired ||
        a.hasAnsweredCurrent != b.hasAnsweredCurrent ||
        a.isHistoryReady != b.isHistoryReady ||
        a.isConnected != b.isConnected ||
        a.errorMessage != b.errorMessage ||
        a.room.status != b.room.status ||
        a.room.race?.isResolved != b.room.race?.isResolved ||
        a.progress.finished != b.progress.finished ||
        a.progress.correctCount != b.progress.correctCount ||
        a.progress.wrongCount != b.progress.wrongCount ||
        a.progress.skippedCount != b.progress.skippedCount,
    builder: (context, state) {
      final question = state.question;
      final isResults = state.room.status == RoomStatus.results;
      return SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Row(
                        children: [
                          Expanded(child: const GameLiveScore()),
                          const SizedBox(width: 12),
                          const Expanded(child: QuestionClock()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (state.room.questionOrigin == 'example')
                        const GameNotice(
                          'Örnek soru havuzu · Gerçek yayın içeriği değildir.',
                        ),
                      if (!state.isConnected)
                        const GameNotice(
                          'Bağlantı bekleniyor. Ortak süre devam ediyor.',
                        ),
                      if (state.errorMessage != null)
                        GameNotice(state.errorMessage!, error: true),
                      PreviousAnswerFeedback(
                        questionIndex: state.questionIndex,
                      ),
                      if (state.questions.isEmpty)
                        const GameNotice(
                          'Bu oyun açılamadı. Uygulamayı güncelleyip yeni bir oda oluştur.',
                        ),
                      if (question != null &&
                          !state.hasExpired &&
                          !isResults) ...[
                        GameCurrentQuestion(
                          key: const ValueKey('question-card'),
                          answerController: answerController,
                          onSubmit: onSubmit,
                        ),
                        if (state.hasAnsweredCurrent) ...[
                          const SizedBox(height: 16),
                          GameNotice(
                            state.room.isRace
                                ? state.room.race!.isResolved
                                      ? 'Bir sonraki soru geliyor…'
                                      : 'Cevabın kaydedildi. Diğer oyuncular yarışıyor.'
                                : 'Cevabın kaydedildi. Süre bitince herkes aynı anda sonraki soruya geçecek.',
                          ),
                        ],
                      ] else if (state.questions.isNotEmpty &&
                          !state.isHistoryReady &&
                          !state.hasExpired &&
                          !isResults) ...[
                        const GameNotice('Soru hazırlanıyor…'),
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
                                  '${state.progress.correctCount} doğru · ${state.progress.wrongCount} bilemedin'
                                  '${state.progress.skippedCount > 0 ? ' · ${state.progress.skippedCount} başkası bildi' : ''}',
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
                      const GameStandings(),
                    ],
                  ),
                ),
                if (question != null && !state.hasExpired && !isResults)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: GameAnswerActions(
                      onSubmit: onSubmit,
                      answerController: answerController,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
