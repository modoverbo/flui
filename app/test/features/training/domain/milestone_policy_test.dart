import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/milestone_policy.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = MilestonePolicy();

  bool retain({
    TrainingContext context = TrainingContext.daily,
    AttemptKind kind = AttemptKind.first,
    bool consent = true,
    bool succeeded = true,
    Duration duration = const Duration(seconds: 15),
    bool hasMilestoneThisWeek = false,
  }) => policy.shouldRetain(
    consentGranted: consent,
    analysisSucceeded: succeeded,
    context: context,
    kind: kind,
    duration: duration,
    hasMilestoneThisIsoWeek: hasMilestoneThisWeek,
  );

  test('diagnosis first attempt always retains with consent', () {
    expect(retain(context: TrainingContext.diagnosis), isTrue);
  });

  test('daily/lab retain only the first qualifying attempt each ISO week', () {
    expect(retain(), isTrue);
    expect(retain(hasMilestoneThisWeek: true), isFalse);
  });

  test('daily/lab below the minimum duration does not retain', () {
    expect(retain(duration: const Duration(seconds: 5)), isFalse);
  });

  test('quick practice never retains audio, even with consent (D33)', () {
    expect(retain(context: TrainingContext.quick), isFalse);
  });

  test('word exercises never retain audio (D37)', () {
    expect(retain(context: TrainingContext.word), isFalse);
  });

  test('no consent means no retention regardless of context', () {
    expect(retain(context: TrainingContext.diagnosis, consent: false), isFalse);
  });

  test('a failed analysis never retains audio', () {
    expect(retain(succeeded: false), isFalse);
  });

  test('only the first attempt kind is ever a milestone', () {
    expect(retain(kind: AttemptKind.repeat), isFalse);
  });
}
