import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../room/domain/entities/game_room.dart';
import '../cubit/game_state.dart';

class GameSoundController {
  GameSoundController({AudioPlayer? hintPlayer, AudioPlayer? tickPlayer})
    : _hintPlayer = hintPlayer ?? AudioPlayer(),
      _tickPlayer = tickPlayer ?? AudioPlayer();

  final AudioPlayer _hintPlayer;
  final AudioPlayer _tickPlayer;
  GameState? _previous;
  Future<void>? _initialization;
  int? _lastTickSecond;
  int _observedHintCount = 0;
  int _playbackGeneration = 0;
  bool _ready = false;
  bool _disposed = false;
  bool _foreground = true;
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> initialize() => _initialization ??= _prepare();

  Future<void> _prepare() async {
    try {
      final context = AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      );
      for (final entry in {
        _hintPlayer: ('audio/letter_reveal.wav', 0.55),
        _tickPlayer: ('audio/clock_tick.wav', 0.4),
      }.entries) {
        if (_disposed) return;
        await entry.key.setAudioContext(context);
        await entry.key.setPlayerMode(PlayerMode.lowLatency);
        await entry.key.setReleaseMode(ReleaseMode.stop);
        await entry.key.setVolume(entry.value.$2);
        await entry.key.setSourceAsset(entry.value.$1);
      }
      _ready = !_disposed;
    } catch (_) {
      // Audio is optional: a device/backend failure must not interrupt gameplay.
      debugPrint('Oyun sesleri yüklenemedi.');
    }
  }

  bool _active(GameState state) =>
      state.clockReady &&
      state.question != null &&
      state.room.status == RoomStatus.playing &&
      !state.isLeaving &&
      !state.hasExpired &&
      state.serverNowMs >= (state.room.startsAtMs ?? state.serverNowMs + 1);

  void update(GameState state) {
    if (_disposed) return;
    final previous = _previous;
    _previous = state;
    if (previous == null || previous.questionIndex != state.questionIndex) {
      _playbackGeneration++;
      _observedHintCount = state.hints.revealedCount;
      _lastTickSecond = null;
      if (previous != null || !_active(state)) unawaited(_silence());
      return;
    }
    final openedLetter = state.hints.revealedCount > _observedHintCount;
    if (openedLetter) _observedHintCount = state.hints.revealedCount;
    if (!_active(state)) {
      if (_active(previous)) {
        _playbackGeneration++;
        unawaited(_silence());
      }
      return;
    }
    final seconds = state.remainingSeconds;
    final tick =
        _active(previous) &&
        seconds >= 1 &&
        seconds <= 5 &&
        seconds < previous.remainingSeconds &&
        (_lastTickSecond == null || seconds < _lastTickSecond!);
    if (tick) _lastTickSecond = seconds;
    if (!_ready || !_foreground || !_enabled) return;
    if (openedLetter && previous.isConnected && state.isConnected) {
      unawaited(_play(_hintPlayer));
    }
    if (tick) unawaited(_play(_tickPlayer));
  }

  Future<void> _play(AudioPlayer player) async {
    final generation = _playbackGeneration;
    try {
      await player.stop();
      if (!_disposed &&
          _foreground &&
          _enabled &&
          generation == _playbackGeneration) {
        await player.resume();
      }
    } catch (_) {
      debugPrint('Oyun sesi çalınamadı.');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _playbackGeneration++;
    _enabled = enabled;
    if (!enabled) await _silence();
  }

  Future<void> setForeground(bool foreground) async {
    if (_foreground == foreground) return;
    _playbackGeneration++;
    _foreground = foreground;
    // Resuming starts from current state; old sound events are not replayed.
    _previous = null;
    if (!foreground) await _silence();
  }

  Future<void> _silence() async {
    if (_disposed) return;
    try {
      await Future.wait([_hintPlayer.stop(), _tickPlayer.stop()]);
    } catch (_) {
      // A backend that failed to initialize may also reject stop().
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _initialization;
    for (final player in [_hintPlayer, _tickPlayer]) {
      try {
        await player.dispose();
      } catch (_) {
        // Failed audio initialization should not prevent leaving the room.
      }
    }
  }
}
