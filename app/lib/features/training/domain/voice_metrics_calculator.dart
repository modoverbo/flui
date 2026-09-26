import 'dart:math' as math;

import 'package:flui/features/speaking/domain/speech_analyzer.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';

/// Derives [VoiceMetrics] from a transcript's timing (pace, pauses, fillers
/// — reusing [SpeechAnalyzer]) and the recording's amplitude samples
/// (volume spread).
final class VoiceMetricsCalculator {
  const new({this._analyzer = const SpeechAnalyzer()});

  final SpeechAnalyzer _analyzer;

  /// Samples at or below this floor are silence, not volume signal.
  static const volumeFloorDb = -50.0;

  VoiceMetrics calculate({
    required SpeechTranscript transcript,
    required List<double> levelsDbfs,
  }) {
    final speaking = _analyzer.analyze(transcript);
    final minutes = transcript.duration.inMilliseconds / 60000;
    return VoiceMetrics(
      wordsPerMinute: speaking.wordsPerMinute,
      longPauses: speaking.longPauses,
      usefulPauses: speaking.usefulPauses,
      fillerCount: speaking.totalFillers,
      fillersPerMinute: speaking.wordsPerMinute == null || minutes <= 0
          ? null
          : speaking.totalFillers / minutes,
      volumeSpreadDb: _volumeSpread(levelsDbfs),
    );
  }

  double? _volumeSpread(List<double> levelsDbfs) {
    final samples = levelsDbfs.where((db) => db > volumeFloorDb).toList();
    if (samples.isEmpty) return null;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance =
        samples.map((db) => (db - mean) * (db - mean)).reduce((a, b) => a + b) /
        samples.length;
    return math.sqrt(variance);
  }
}
