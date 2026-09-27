import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/training_context.dart';

/// Whether a just-analyzed attempt's audio should be retained (design D7,
/// part-3 §5): diagnosis baseline/retake attempts, plus at most one
/// representative attempt per ISO week for daily/lab. `quick` and `word`
/// never retain audio, regardless of consent (D33, D37).
final class MilestonePolicy {
  const new();

  static const minMilestoneDuration = Duration(seconds: 10);

  bool shouldRetain({
    required bool consentGranted,
    required bool analysisSucceeded,
    required TrainingContext context,
    required AttemptKind kind,
    required Duration duration,
    required bool hasMilestoneThisIsoWeek,
  }) {
    if (!consentGranted || !analysisSucceeded) return false;
    if (kind != AttemptKind.first) return false;
    return switch (context) {
      TrainingContext.diagnosis => true,
      TrainingContext.daily || TrainingContext.lab =>
        duration >= minMilestoneDuration && !hasMilestoneThisIsoWeek,
      TrainingContext.word || TrainingContext.quick => false,
    };
  }
}
