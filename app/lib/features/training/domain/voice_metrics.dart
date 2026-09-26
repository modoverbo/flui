import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_metrics.freezed.dart';

/// Raw, never-scored voice/fluency signals for one attempt (design D12:
/// computed client-side, deterministic, never judged by the LLM).
@freezed
abstract class VoiceMetrics with _$VoiceMetrics {
  const factory({
    required int longPauses,
    required int usefulPauses,
    required int fillerCount,
    int? wordsPerMinute,
    double? fillersPerMinute,
    double? volumeSpreadDb,
  }) = _VoiceMetrics;
}
