import 'package:flui/core/audio/amplitude_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmplitudePipeline.normalize', () {
    test('the -60 dBFS floor maps to rest (near 0)', () {
      final pipeline = AmplitudePipeline();
      expect(pipeline.normalize(-60), lessThan(0.02));
      expect(pipeline.normalize(-60), greaterThanOrEqualTo(0));
    });

    test('quieter than the floor still clamps to rest, not negative', () {
      final pipeline = AmplitudePipeline();
      expect(pipeline.normalize(-90), equals(0));
    });

    test('a loud sample maps near the ceiling (near 1)', () {
      final pipeline = AmplitudePipeline();
      expect(pipeline.normalize(-1), greaterThan(0.9));
      expect(pipeline.normalize(0), equals(1));
    });

    test('louder than the ceiling still clamps to 1, never overshoots', () {
      final pipeline = AmplitudePipeline();
      expect(pipeline.normalize(10), equals(1));
    });

    test('NaN cannot escape the clamp', () {
      final pipeline = AmplitudePipeline();
      final result = pipeline.normalize(double.nan);
      expect(result.isFinite, isTrue);
      expect(result, inInclusiveRange(0, 1));
    });

    test('positive and negative infinity cannot escape the clamp', () {
      final pipeline = AmplitudePipeline();
      expect(pipeline.normalize(double.infinity), equals(1));
      expect(pipeline.normalize(double.negativeInfinity), equals(0));
    });
  });

  group('AmplitudePipeline.addSample (envelope follower)', () {
    test('starts at rest', () {
      final pipeline = AmplitudePipeline();
      expect(pipeline.smoothed, equals(0));
    });

    test('a step from silence to loud converges smoothly over several frames, '
        'never jumping to the target on frame 1', () {
      final pipeline = AmplitudePipeline();
      // Settle at silence first.
      for (var i = 0; i < 5; i++) {
        pipeline.addSample(-60);
      }
      expect(pipeline.smoothed, lessThan(0.02));

      final samples = <double>[];
      for (var i = 0; i < 10; i++) {
        samples.add(pipeline.addSample(0)); // loud, target = 1.0
      }

      // Frame 1 must not equal the target: it's an approach, not a jump.
      expect(samples.first, lessThan(0.9));
      expect(samples.first, greaterThan(0));

      // Monotonically increasing towards the target (attack phase).
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
      }

      // Bounded: never exceeds the normalised ceiling.
      for (final value in samples) {
        expect(value, lessThanOrEqualTo(1));
      }

      // Converging towards, but likely not yet at, the target within 10
      // frames given the chosen release/attack constants.
      expect(samples.last, greaterThan(samples.first));
    });

    test(
      'release is slower than attack: a drop to silence decays gradually',
      () {
        final pipeline = AmplitudePipeline();
        for (var i = 0; i < 10; i++) {
          pipeline.addSample(0); // drive to loud first
        }
        final loud = pipeline.smoothed;
        expect(loud, greaterThan(0.9));

        final afterOneQuietSample = pipeline.addSample(-60);
        // One quiet sample should not collapse it straight back to rest.
        expect(afterOneQuietSample, greaterThan(0.5));
        expect(afterOneQuietSample, lessThan(loud));
      },
    );

    test(
      'NaN / Infinity samples cannot escape the clamp or produce NaN state',
      () {
        final pipeline = AmplitudePipeline()..addSample(0);
        final afterNaN = pipeline.addSample(double.nan);
        expect(afterNaN.isFinite, isTrue);
        expect(afterNaN, inInclusiveRange(0, 1));

        final afterInf = pipeline.addSample(double.infinity);
        expect(afterInf.isFinite, isTrue);
        expect(afterInf, inInclusiveRange(0, 1));

        final afterNegInf = pipeline.addSample(double.negativeInfinity);
        expect(afterNegInf.isFinite, isTrue);
        expect(afterNegInf, inInclusiveRange(0, 1));
      },
    );

    test('reset returns the smoothed value to rest', () {
      final pipeline = AmplitudePipeline()..addSample(0);
      expect(pipeline.smoothed, greaterThan(0));
      pipeline.reset();
      expect(pipeline.smoothed, equals(0));
    });
  });
}
