import 'package:flui/features/training/domain/feedback.dart';
import 'package:meta/meta.dart';

/// Where a HOY/lab loop resumes when the user returns mid-session (design
/// part-3 §7).
sealed class LoopResumeDecision {
  const new();
}

final class ResumeAtStart extends LoopResumeDecision {
  const new();
}

final class ResumeAtRepeat extends LoopResumeDecision {
  const new({required this.storedFeedback});

  final Feedback storedFeedback;
}

/// Today's session state as far as the loop got, as read back from
/// persisted attempts (no new schema — same principle as D38).
@immutable
final class TodayLoopProgress {
  const new({required this.repeatCompleted, this.firstAttemptFeedback});

  final Feedback? firstAttemptFeedback;
  final bool repeatCompleted;
}

/// Resumes today's HOY/lab loop at the repeat step (with its stored
/// feedback) when the first attempt is already analyzed and the repeat is
/// not yet done; otherwise starts fresh.
final class LoopResumePolicy {
  const new();

  LoopResumeDecision decide(TodayLoopProgress? progress) {
    if (progress == null) return const ResumeAtStart();
    final feedback = progress.firstAttemptFeedback;
    if (feedback != null && !progress.repeatCompleted) {
      return ResumeAtRepeat(storedFeedback: feedback);
    }
    return const ResumeAtStart();
  }
}
