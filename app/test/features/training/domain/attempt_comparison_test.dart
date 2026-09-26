import 'package:flui/features/training/domain/attempt_comparison.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

const ObservationSource _ai = ObservationSource.ai;

Observation _obs(BehaviorCode code) => Observation(code: code, source: _ai);

VoiceMetrics _metrics({int fillerCount = 0, double? fillersPerMinute}) =>
    VoiceMetrics(
      longPauses: 0,
      usefulPauses: 0,
      fillerCount: fillerCount,
      fillersPerMinute: fillersPerMinute,
    );

void main() {
  group('observation changes', () {
    test('an opportunity present in first but not repeat resolves', () {
      final comparison = AttemptComparison.between(
        firstObservations: [_obs(BehaviorCode.fillerHeavy)],
        repeatObservations: const [],
        firstMetrics: _metrics(),
        repeatMetrics: _metrics(),
      );

      expect(comparison.observationChanges, [
        const ObservationChange(
          code: BehaviorCode.fillerHeavy,
          kind: ObservationChangeKind.resolved,
        ),
      ]);
    });

    test('an opportunity present in both persists', () {
      final comparison = AttemptComparison.between(
        firstObservations: [_obs(BehaviorCode.noClosing)],
        repeatObservations: [_obs(BehaviorCode.noClosing)],
        firstMetrics: _metrics(),
        repeatMetrics: _metrics(),
      );

      expect(comparison.observationChanges, [
        const ObservationChange(
          code: BehaviorCode.noClosing,
          kind: ObservationChangeKind.persisted,
        ),
      ]);
    });

    test('an opportunity absent in first but present in repeat appears', () {
      final comparison = AttemptComparison.between(
        firstObservations: const [],
        repeatObservations: [_obs(BehaviorCode.vagueWord)],
        firstMetrics: _metrics(),
        repeatMetrics: _metrics(),
      );

      expect(comparison.observationChanges, [
        const ObservationChange(
          code: BehaviorCode.vagueWord,
          kind: ObservationChangeKind.appeared,
        ),
      ]);
    });
  });

  group('metric changes (no raw delta number)', () {
    test('fewer fillers on the repeat is an observable improvement', () {
      final comparison = AttemptComparison.between(
        firstObservations: const [],
        repeatObservations: const [],
        firstMetrics: _metrics(fillerCount: 5, fillersPerMinute: 10),
        repeatMetrics: _metrics(fillerCount: 1, fillersPerMinute: 2),
      );

      expect(comparison.metricChanges, [
        const MetricChange(
          kind: MetricKind.fillers,
          direction: MetricDirection.improved,
        ),
      ]);
    });

    test('more fillers on the repeat is an observable regression', () {
      final comparison = AttemptComparison.between(
        firstObservations: const [],
        repeatObservations: const [],
        firstMetrics: _metrics(fillerCount: 1, fillersPerMinute: 2),
        repeatMetrics: _metrics(fillerCount: 5, fillersPerMinute: 10),
      );

      expect(comparison.metricChanges, [
        const MetricChange(
          kind: MetricKind.fillers,
          direction: MetricDirection.worsened,
        ),
      ]);
    });

    test('never exposes a raw filler-count number anywhere', () {
      final comparison = AttemptComparison.between(
        firstObservations: const [],
        repeatObservations: const [],
        firstMetrics: _metrics(fillerCount: 5, fillersPerMinute: 10),
        repeatMetrics: _metrics(fillerCount: 1, fillersPerMinute: 2),
      );

      expect(comparison.toString(), isNot(contains(RegExp('[0-9]'))));
    });
  });

  group('isMateriallySame', () {
    test('true when every change is persisted/steady (no forced claim)', () {
      final comparison = AttemptComparison.between(
        firstObservations: [_obs(BehaviorCode.noClosing)],
        repeatObservations: [_obs(BehaviorCode.noClosing)],
        firstMetrics: _metrics(fillerCount: 2, fillersPerMinute: 4),
        repeatMetrics: _metrics(fillerCount: 2, fillersPerMinute: 4),
      );

      expect(comparison.isMateriallySame, isTrue);
    });

    test('false when any change resolved/appeared/improved/worsened', () {
      final comparison = AttemptComparison.between(
        firstObservations: [_obs(BehaviorCode.fillerHeavy)],
        repeatObservations: const [],
        firstMetrics: _metrics(),
        repeatMetrics: _metrics(),
      );

      expect(comparison.isMateriallySame, isFalse);
    });

    test('true (not falsely improved) with no observations and no metrics '
        'at all', () {
      final comparison = AttemptComparison.between(
        firstObservations: const [],
        repeatObservations: const [],
        firstMetrics: _metrics(),
        repeatMetrics: _metrics(),
      );

      expect(comparison.isMateriallySame, isTrue);
      expect(comparison.observationChanges, isEmpty);
      expect(comparison.metricChanges, isEmpty);
    });
  });
}
