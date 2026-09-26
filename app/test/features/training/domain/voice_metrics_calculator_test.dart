import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/domain/voice_metrics_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

SpeechTranscript _transcript({
  required List<String> words,
  required double gapSeconds,
  Duration duration = const Duration(seconds: 20),
}) {
  var cursor = 0.0;
  final speechWords = <SpeechWord>[];
  for (final word in words) {
    final start = cursor;
    final end = start + 0.3;
    speechWords.add(
      SpeechWord(text: word, startSeconds: start, endSeconds: end),
    );
    cursor = end + gapSeconds;
  }
  return SpeechTranscript(
    text: words.join(' '),
    words: speechWords,
    duration: duration,
  );
}

void main() {
  const calculator = VoiceMetricsCalculator();

  group('VoiceMetricsCalculator.calculate', () {
    test('reuses SpeechAnalyzer for words-per-minute/pauses/fillers', () {
      final words = List.generate(20, (i) => 'palabra$i');
      final transcript = _transcript(
        words: words,
        gapSeconds: .1,
        duration: const Duration(seconds: 10),
      );

      final metrics = calculator.calculate(
        transcript: transcript,
        levelsDbfs: const [],
      );

      expect(metrics.wordsPerMinute, 120);
      expect(metrics.longPauses, 0);
      expect(metrics.usefulPauses, 0);
      expect(metrics.fillerCount, 0);
      expect(metrics.fillersPerMinute, 0);
    });

    test('too few words leaves the pace unreliable (null)', () {
      final transcript = _transcript(
        words: ['hola', 'como', 'estas'],
        gapSeconds: .1,
      );

      final metrics = calculator.calculate(
        transcript: transcript,
        levelsDbfs: const [],
      );

      expect(metrics.wordsPerMinute, isNull);
      expect(metrics.fillersPerMinute, isNull);
    });

    test('volume spread is the stddev of levels above the -50 dBFS floor', () {
      final words = List.generate(20, (i) => 'palabra$i');
      final transcript = _transcript(words: words, gapSeconds: .1);

      final metrics = calculator.calculate(
        transcript: transcript,
        // -60 is below the floor and dropped; -40/-30/-20 stay.
        levelsDbfs: const [-60, -40, -30, -20],
      );

      // mean(-40,-30,-20) = -30; variance = ((10)^2+(0)^2+(10)^2)/3 = 66.67
      expect(metrics.volumeSpreadDb, closeTo(8.16, 0.01));
    });

    test('empty levelsDbfs yields a null volume spread, never zero', () {
      final words = List.generate(20, (i) => 'palabra$i');
      final transcript = _transcript(words: words, gapSeconds: .1);

      final metrics = calculator.calculate(
        transcript: transcript,
        levelsDbfs: const [],
      );

      expect(metrics.volumeSpreadDb, isNull);
    });

    test('a below-floor-only sample also yields a null volume spread', () {
      final words = List.generate(20, (i) => 'palabra$i');
      final transcript = _transcript(words: words, gapSeconds: .1);

      final metrics = calculator.calculate(
        transcript: transcript,
        levelsDbfs: const [-55, -60, -70],
      );

      expect(metrics.volumeSpreadDb, isNull);
    });
  });

  group('VoiceMetrics', () {
    test('is a plain value object (equality, no infra)', () {
      const a = VoiceMetrics(
        wordsPerMinute: 120,
        longPauses: 0,
        usefulPauses: 1,
        fillerCount: 0,
        fillersPerMinute: 0,
      );
      const b = VoiceMetrics(
        wordsPerMinute: 120,
        longPauses: 0,
        usefulPauses: 1,
        fillerCount: 0,
        fillersPerMinute: 0,
      );
      expect(a, b);
    });
  });
}
