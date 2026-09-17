import 'package:flui/features/speaking/domain/speech_analyzer.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

SpeechTranscript transcript({
  required String text,
  required List<SpeechWord> words,
  Duration duration = const Duration(seconds: 30),
}) => SpeechTranscript(text: text, words: words, duration: duration);

SpeechWord word(String text, double start, double end) =>
    SpeechWord(text: text, startSeconds: start, endSeconds: end);

void main() {
  const analyzer = SpeechAnalyzer();

  test('calculates words per minute when there is enough speech', () {
    final words = List.generate(
      30,
      (index) => word('palabra', index.toDouble(), index + .4),
    );
    final result = analyzer.analyze(
      transcript(text: List.filled(30, 'palabra').join(' '), words: words),
    );

    expect(result.wordsPerMinute, 60);
    expect(result.hasEnoughSpeech, isTrue);
  });

  test('omits pace metrics below fifteen words', () {
    final words = List.generate(
      14,
      (index) => word('idea', index.toDouble(), index + .4),
    );
    final result = analyzer.analyze(
      transcript(text: List.filled(14, 'idea').join(' '), words: words),
    );

    expect(result.wordsPerMinute, isNull);
    expect(result.hasEnoughSpeech, isFalse);
  });

  test('counts intentional and long timestamp gaps', () {
    final result = analyzer.analyze(
      transcript(
        text: 'una idea clara y final',
        words: [
          word('una', 0, .3),
          word('idea', .4, .8),
          word('clara', 1.6, 2),
          word('y', 4.2, 4.4),
          word('final', 4.5, 5),
        ],
      ),
    );

    expect(result.usefulPauses, 1);
    expect(result.longPauses, 1);
  });

  test('detects Spanish filler phrases without double counting', () {
    final result = analyzer.analyze(
      transcript(
        text: 'Eh, pues yo o sea creo como que este tema sirve. Eh.',
        words: List.generate(
          12,
          (index) => word('x', index.toDouble(), index + .3),
        ),
      ),
    );

    expect(result.fillerCounts['eh'], 2);
    expect(result.fillerCounts['pues'], 1);
    expect(result.fillerCounts['o sea'], 1);
    expect(result.fillerCounts['como que'], 1);
    expect(result.fillerCounts['este'], 1);
    expect(result.totalFillers, 6);
  });

  test('flags repeated content words while ignoring short function words', () {
    final result = analyzer.analyze(
      transcript(
        text: 'La propuesta mejora porque la propuesta concreta funciona',
        words: List.generate(
          8,
          (index) => word('x', index.toDouble(), index + .3),
        ),
      ),
    );

    expect(result.repeatedWords, containsPair('propuesta', 2));
    expect(result.repeatedWords, isNot(contains('la')));
  });

  test('feedback selects no more than three signals and a retry cue', () {
    final words = List.generate(
      40,
      (index) => word('palabra', index * .3, index * .3 + .2),
    );
    final metrics = analyzer.analyze(
      transcript(
        text: '${List.filled(35, 'palabra').join(' ')} eh eh eh pues',
        words: words,
        duration: const Duration(seconds: 15),
      ),
    );
    final feedback = analyzer.feedback(metrics);

    expect(feedback.signals, hasLength(3));
    expect(feedback.retryCue, isNotEmpty);
    expect(
      feedback.signals.any((signal) => signal.title == 'Muletillas'),
      isTrue,
    );
  });
}
