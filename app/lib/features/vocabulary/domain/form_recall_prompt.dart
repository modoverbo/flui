import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:meta/meta.dart';

/// Form recall prompt: the word's explanation plus its example sentence with
/// the word masked. The cloze sentences are kept fresh for the end-of-session
/// check, so the example sentence is used instead.
@immutable
final class FormRecallPrompt {
  const new({
    required this.explanation,
    required this.expectedForm,
    this.before,
    this.after,
  });

  factory forWord(Word word) {
    final sentence = word.exampleSentence;
    final span = word.forms.findIn(sentence);
    if (span == null) {
      return FormRecallPrompt(
        explanation: word.explanation,
        expectedForm: word.lemma,
      );
    }
    return FormRecallPrompt(
      explanation: word.explanation,
      expectedForm: sentence.substring(span.start, span.end),
      before: sentence.substring(0, span.start),
      after: sentence.substring(span.end),
    );
  }

  final String explanation;

  /// The masked form, as written in the sentence (for example "zanjó").
  final String expectedForm;
  final String? before;
  final String? after;

  bool get hasSentence => before != null && after != null;
}
