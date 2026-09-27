import 'package:flui/features/training/domain/attempt_comparison.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/progression.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

const ObservationSource _ai = ObservationSource.ai;

Observation _obs(BehaviorCode code) => Observation(code: code, source: _ai);

const _emptyMetrics = VoiceMetrics(
  longPauses: 0,
  usefulPauses: 0,
  fillerCount: 0,
);

void main() {
  const progression = Progression();

  group('LoopOutcome.fromComparison', () {
    test('improved when the focus behavior resolved between attempts', () {
      final comparison = AttemptComparison.between(
        firstObservations: [_obs(BehaviorCode.noClosing)],
        repeatObservations: const [],
        firstMetrics: _emptyMetrics,
        repeatMetrics: _emptyMetrics,
      );

      final outcome = LoopOutcome.fromComparison(
        context: TrainingContext.daily,
        focusBehavior: BehaviorCode.noClosing,
        comparison: comparison,
      );

      expect(outcome.improved, isTrue);
    });

    test('not improved when the focus behavior persists into the repeat', () {
      final comparison = AttemptComparison.between(
        firstObservations: [_obs(BehaviorCode.noClosing)],
        repeatObservations: [_obs(BehaviorCode.noClosing)],
        firstMetrics: _emptyMetrics,
        repeatMetrics: _emptyMetrics,
      );

      final outcome = LoopOutcome.fromComparison(
        context: TrainingContext.daily,
        focusBehavior: BehaviorCode.noClosing,
        comparison: comparison,
      );

      expect(outcome.improved, isFalse);
    });

    test('not improved when the resolved code is a different behavior', () {
      final comparison = AttemptComparison.between(
        firstObservations: [_obs(BehaviorCode.vagueWord)],
        repeatObservations: const [],
        firstMetrics: _emptyMetrics,
        repeatMetrics: _emptyMetrics,
      );

      final outcome = LoopOutcome.fromComparison(
        context: TrainingContext.daily,
        focusBehavior: BehaviorCode.noClosing,
        comparison: comparison,
      );

      expect(outcome.improved, isFalse);
    });
  });

  group('levelFor', () {
    test('advances one level after 3 improved loops', () {
      final outcomes = List.generate(
        3,
        (_) =>
            const LoopOutcome(context: TrainingContext.daily, improved: true),
      );

      expect(progression.levelFor(currentLevel: 1, outcomes: outcomes), 2);
    });

    test(
      'a non-improved loop resets the streak without lowering the level',
      () {
        final outcomes = [
          const LoopOutcome(context: TrainingContext.daily, improved: true),
          const LoopOutcome(context: TrainingContext.daily, improved: true),
          const LoopOutcome(context: TrainingContext.daily, improved: false),
          const LoopOutcome(context: TrainingContext.daily, improved: true),
          const LoopOutcome(context: TrainingContext.daily, improved: true),
        ];

        expect(progression.levelFor(currentLevel: 1, outcomes: outcomes), 1);
      },
    );

    test('quick-practice outcomes are ignored (D33: never form loops)', () {
      final outcomes = List.generate(
        3,
        (_) =>
            const LoopOutcome(context: TrainingContext.quick, improved: true),
      );

      expect(progression.levelFor(currentLevel: 1, outcomes: outcomes), 1);
    });

    test('multiple full cycles advance multiple levels', () {
      final outcomes = List.generate(
        6,
        (_) => const LoopOutcome(context: TrainingContext.lab, improved: true),
      );

      expect(progression.levelFor(currentLevel: 1, outcomes: outcomes), 3);
    });
  });
}
