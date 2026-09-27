import 'package:flui/core/audio/data/bytes_source.dart';

/// Fallback for a platform that is neither `dart.library.io` nor
/// `dart.library.html` (none of flui's targets — Web, Android, iOS — hit
/// this; kept so the conditional import in `just_audio_speech_player.dart`
/// fails loudly instead of silently picking the wrong platform).
InMemoryAudioSource createInMemoryAudioSource() => throw UnsupportedError(
  'No InMemoryAudioSource implementation for this platform.',
);
