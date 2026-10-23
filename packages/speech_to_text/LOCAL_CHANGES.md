Based on speech_to_text 7.6.0-beta.4 (https://github.com/csdcorp/speech_to_text).
The upstream license is retained in LICENSE. Runtime Dart/Android/Darwin sources
are kept here so release builds use the same fix as local builds, without
modifying the user's pub cache.

Local changes:
- Android reports listening from onReadyForSpeech, while tracking pending start
  separately so cancel still works before readiness.
- Dart listen/pause timers start at native readiness, not at the listen request.
- iOS reports readiness after AVAudioEngine.start; optional startup sounds cannot
  report it early. Recording haptics are enabled by the app's listen options.

- Foreground answer screens can prepare a 300ms microphone pre-roll in RAM.
  `begin_audio_buffer` freezes that prefix at the answer tap and retains incoming
  samples during sound shutdown and recognizer startup. Capture is capped at 3s
  from that tap; the prefix adds at most 300ms. No audio files are created.
- iOS appends the prefix and live PCM to SFSpeechAudioBufferRecognitionRequest
  in order, reusing its already-running AVAudioEngine.
- Android 13+ streams 16kHz mono PCM16 through EXTRA_AUDIO_SOURCE. This requires
  recognition-service support. Older Android versions retain normal native
  recognition/readiness; no cloud provider is introduced as a fallback.
- Android attaches the PCM pipe after queued recognizer-intent setup, so rebuilding
  the language/options request cannot discard the audio source. Contextual bias
  strings use the ArrayList type required by the Android recognition service.
- Native app-pause/interruption hooks and widget ownership close capture, clear
  samples and release pipes on background, question change, completion or exit.
  Preparation does not transcribe or send audio. The existing system recognizer
  may process the selected answer window through Apple's/Google's service.

No background recording or new recognition provider has been added.
Recheck these changes when upgrading.
