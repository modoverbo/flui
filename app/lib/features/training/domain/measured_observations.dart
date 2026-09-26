import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';

/// Turns raw [VoiceMetrics] into client-measured [Observation]s using named
/// thresholds (design part-3 §7). Each metric yields at most one
/// observation: an opportunity when it crosses its threshold, otherwise a
/// matching strength — never both, never a raw number.
final class MeasuredObservations {
  const new();

  static const fastWpm = 170;
  static const slowWpm = 100;
  static const fillerHeavyPerMinute = 6;
  static const longPausesLimit = 3;
  static const volumeUnstableDb = 9;

  List<Observation> from(VoiceMetrics metrics) => [
    ..._pace(metrics.wordsPerMinute),
    ..._pauses(
      longPauses: metrics.longPauses,
      usefulPauses: metrics.usefulPauses,
    ),
    ..._fillers(metrics.fillersPerMinute),
    ..._volume(metrics.volumeSpreadDb),
  ];

  List<Observation> _pace(int? wordsPerMinute) {
    if (wordsPerMinute == null) return const [];
    final code = wordsPerMinute > fastWpm
        ? BehaviorCode.paceFast
        : wordsPerMinute < slowWpm
        ? BehaviorCode.paceSlow
        : BehaviorCode.steadyPace;
    return [_measured(code)];
  }

  List<Observation> _pauses({
    required int longPauses,
    required int usefulPauses,
  }) {
    if (longPauses > longPausesLimit) {
      return [_measured(BehaviorCode.longPauses)];
    }
    if (usefulPauses > 0) return [_measured(BehaviorCode.usefulPauses)];
    return const [];
  }

  List<Observation> _fillers(double? fillersPerMinute) {
    if (fillersPerMinute == null) return const [];
    final code = fillersPerMinute >= fillerHeavyPerMinute
        ? BehaviorCode.fillerHeavy
        : BehaviorCode.controlledFillers;
    return [_measured(code)];
  }

  List<Observation> _volume(double? volumeSpreadDb) {
    if (volumeSpreadDb == null) return const [];
    final code = volumeSpreadDb > volumeUnstableDb
        ? BehaviorCode.volumeUnstable
        : BehaviorCode.steadyVolume;
    return [_measured(code)];
  }

  Observation _measured(BehaviorCode code) =>
      Observation(code: code, source: ObservationSource.measured);
}
