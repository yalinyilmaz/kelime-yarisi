import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/studio_components.dart';
import '../../../room/domain/entities/game_room.dart';
import '../cubit/game_state.dart';
import 'game_actions.dart';
import 'game_notice.dart';
import 'game_question_card.dart';
import 'game_score_card.dart';
import 'game_scoreboard.dart';
import 'previous_answer_feedback.dart';
import 'question_clock.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({
    required this.state,
    required this.answerController,
    required this.onSubmit,
    required this.onGiveUp,
    super.key,
  });
  final GameState state;
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
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
                        Expanded(
                          child: GameScoreCard(score: state.progress.score),
                        ),
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
                    PreviousAnswerFeedback(questionIndex: state.questionIndex),
                    if (state.questions.isEmpty)
                      const GameNotice(
                        'Bu oyun açılamadı. Uygulamayı güncelleyip yeni bir oda oluştur.',
                      ),
                    if (question != null &&
                        !state.hasExpired &&
                        !isResults) ...[
                      GameQuestionCard(
                        key: const ValueKey('question-card'),
                        state: state,
                        answerController: answerController,
                        onSubmitted: onSubmit,
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
                    GameScoreboard(state: state),
                  ],
                ),
              ),
              if (question != null && !state.hasExpired && !isResults)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: GameActions(state: state, onSubmit: onSubmit),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
