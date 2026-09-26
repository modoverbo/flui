import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/measured_observations.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceMetrics _metrics({
  int? wpm,
  int longPauses = 0,
  int usefulPauses = 0,
  double? fillersPerMinute,
  double? volumeSpreadDb,
}) => VoiceMetrics(
  wordsPerMinute: wpm,
  longPauses: longPauses,
  usefulPauses: usefulPauses,
  fillerCount: 0,
  fillersPerMinute: fillersPerMinute,
  volumeSpreadDb: volumeSpreadDb,
);

List<BehaviorCode> _codes(List<Observation> observations) =>
    observations.map((o) => o.code).toList();

void main() {
  const measured = MeasuredObservations();

  group('named thresholds', () {
    test('are exactly the values design part-3 §7 requires', () {
      expect(MeasuredObservations.fastWpm, 170);
      expect(MeasuredObservations.slowWpm, 100);
      expect(MeasuredObservations.fillerHeavyPerMinute, 6);
      expect(MeasuredObservations.longPausesLimit, 3);
      expect(MeasuredObservations.volumeUnstableDb, 9);
    });
  });

  group('pace', () {
    test('at the fast boundary (170) is still steady', () {
      final observations = measured.from(_metrics(wpm: 170));
      expect(_codes(observations), contains(BehaviorCode.steadyPace));
      expect(_codes(observations), isNot(contains(BehaviorCode.paceFast)));
    });

    test('above the fast boundary (171) is an opportunity', () {
      final observations = measured.from(_metrics(wpm: 171));
      expect(_codes(observations), contains(BehaviorCode.paceFast));
    });

    test('at the slow boundary (100) is still steady', () {
      final observations = measured.from(_metrics(wpm: 100));
      expect(_codes(observations), contains(BehaviorCode.steadyPace));
    });

    test('below the slow boundary (99) is an opportunity', () {
      final observations = measured.from(_metrics(wpm: 99));
      expect(_codes(observations), contains(BehaviorCode.paceSlow));
    });

    test('unreliable pace (null wpm) yields no pace observation at all', () {
      final observations = measured.from(_metrics());
      expect(
        _codes(observations),
        isNot(
          anyOf(
            contains(BehaviorCode.paceFast),
            contains(BehaviorCode.paceSlow),
            contains(BehaviorCode.steadyPace),
          ),
        ),
      );
    });
  });

  group('fillers', () {
    test('at the heavy boundary (6/min) is an opportunity', () {
      final observations = measured.from(_metrics(fillersPerMinute: 6));
      expect(_codes(observations), contains(BehaviorCode.fillerHeavy));
    });

    test('just under the boundary (5.9/min) is controlled', () {
      final observations = measured.from(_metrics(fillersPerMinute: 5.9));
      expect(_codes(observations), contains(BehaviorCode.controlledFillers));
    });
  });

  group('pauses', () {
    test('over the limit (4 > 3) is an opportunity, no useful-pauses '
        'strength alongside it', () {
      final observations = measured.from(
        _metrics(longPauses: 4, usefulPauses: 2),
      );
      expect(_codes(observations), contains(BehaviorCode.longPauses));
      expect(_codes(observations), isNot(contains(BehaviorCode.usefulPauses)));
    });

    test('at the limit (3) with useful pauses present is a strength', () {
      final observations = measured.from(
        _metrics(longPauses: 3, usefulPauses: 1),
      );
      expect(_codes(observations), contains(BehaviorCode.usefulPauses));
      expect(_codes(observations), isNot(contains(BehaviorCode.longPauses)));
    });

    test('no long pauses and no useful pauses is silent (nothing to say)', () {
      final observations = measured.from(_metrics());
      expect(
        _codes(observations),
        isNot(
          anyOf(
            contains(BehaviorCode.longPauses),
            contains(BehaviorCode.usefulPauses),
          ),
        ),
      );
    });
  });

  group('volume', () {
    test('at the unstable boundary (9 dB) is still steady', () {
      final observations = measured.from(_metrics(volumeSpreadDb: 9));
      expect(_codes(observations), contains(BehaviorCode.steadyVolume));
    });

    test('above the boundary (9.1 dB) is an opportunity', () {
      final observations = measured.from(_metrics(volumeSpreadDb: 9.1));
      expect(_codes(observations), contains(BehaviorCode.volumeUnstable));
    });

    test('unavailable spread (null) yields no volume observation', () {
      final observations = measured.from(_metrics());
      expect(
        _codes(observations),
        isNot(
          anyOf(
            contains(BehaviorCode.volumeUnstable),
            contains(BehaviorCode.steadyVolume),
          ),
        ),
      );
    });
  });

  test('every produced observation is source=measured', () {
    final observations = measured.from(
      _metrics(
        wpm: 200,
        longPauses: 5,
        fillersPerMinute: 8,
        volumeSpreadDb: 12,
      ),
    );
    expect(observations, isNotEmpty);
    for (final observation in observations) {
      expect(observation.source, ObservationSource.measured);
    }
  });
}
