import 'dart:typed_data';

import 'package:meta/meta.dart';

/// One finished hold-to-record capture: encoded audio bytes plus enough
/// metadata to analyze, play back, or upload it.
///
/// [levelsDbfs] holds the raw amplitude samples observed during capture
/// (recorder cadence, ~120ms per sample per `RecordSpeechRecorder`) — later
/// feeds `VoiceMetrics`' volume-stability calculation (design §7).
@immutable
final class RecordedAudio {
  const new({
    required this.bytes,
    required this.mimeType,
    required this.duration,
    required this.levelsDbfs,
  });

  final Uint8List bytes;
  final String mimeType;
  final Duration duration;
  final List<double> levelsDbfs;
}
