import 'package:flui/features/training/domain/feedback.dart';
import 'package:flui/features/training/domain/loop_resume_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = LoopResumePolicy();
  const feedback = Feedback(retryCue: 'Sigue así.');

  test('no session today resumes at the start', () {
    expect(policy.decide(null), const ResumeAtStart());
  });

  test('a first attempt without a completed repeat resumes at the repeat', () {
    final decision = policy.decide(
      const TodayLoopProgress(
        firstAttemptFeedback: feedback,
        repeatCompleted: false,
      ),
    );

    expect(decision, isA<ResumeAtRepeat>());
    expect((decision as ResumeAtRepeat).storedFeedback, feedback);
  });

  test(
    'a completed repeat resumes at the start (the next loop, not this one)',
    () {
      final decision = policy.decide(
        const TodayLoopProgress(
          firstAttemptFeedback: feedback,
          repeatCompleted: true,
        ),
      );

      expect(decision, const ResumeAtStart());
    },
  );

  test('no first attempt yet resumes at the start', () {
    final decision = policy.decide(
      const TodayLoopProgress(repeatCompleted: false),
    );

    expect(decision, const ResumeAtStart());
  });
}
