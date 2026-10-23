import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../audio/game_sound_controller.dart';
import 'game_cubit.dart';
import 'game_state.dart';

class GameAudioCubit extends Cubit<bool> {
  GameAudioCubit(GameCubit game, {GameSoundController? sounds})
    : _sounds = sounds ?? GameSoundController(),
      super(sounds?.enabled ?? true) {
    _sounds.update(game.state);
    _subscription = game.stream.listen(_sounds.update);
    unawaited(_sounds.initialize());
  }

  final GameSoundController _sounds;
  late final StreamSubscription<GameState> _subscription;
  bool _foreground = true;
  bool _speechListening = false;

  void toggle() {
    emit(!state);
    unawaited(_sounds.setEnabled(state));
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    unawaited(_sounds.setForeground(_foreground && !_speechListening));
  }

  Future<void> setSpeechListening(bool listening) {
    _speechListening = listening;
    return _sounds.setForeground(_foreground && !listening);
  }

  Future<void> prepareMicrophone() => _sounds.prepareMicrophone();

  @override
  Future<void> close() async {
    await Future.wait([
      _subscription.cancel(),
      super.close(),
      _sounds.dispose(),
    ]);
  }
}
