import 'package:flui/features/exercises/domain/text_matching.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:meta/meta.dart';

enum ProductionIssue { tooShort, missingWord }

/// "Úsala": the user's own sentence must use the word (any form) and have at
/// least [minWords] words. Meaning and register are self-checked.
abstract final class ProductionCheck {
  static const minWords = 4;

  static ProductionIssue? validate(String sentence, WordForms forms) {
    if (wordTokens(sentence).length < minWords) {
      return ProductionIssue.tooShort;
    }
    if (!forms.appearsIn(sentence)) return ProductionIssue.missingWord;
    return null;
  }
}

enum ProductionPhase { writing, selfCheck, accepted }

/// Writing → "¿Suena natural?" → accepted (`production_done = true`).
@immutable
final class ProductionFlow {
  const new({
    required this.forms,
    this.phase = ProductionPhase.writing,
    this.sentence = '',
    this.issue,
  });

  final WordForms forms;
  final ProductionPhase phase;
  final String sentence;
  final ProductionIssue? issue;

  bool get isAccepted => phase == ProductionPhase.accepted;

  ProductionFlow submit(String text) {
    if (phase != ProductionPhase.writing) return this;
    final issue = ProductionCheck.validate(text, forms);
    return ProductionFlow(
      forms: forms,
      phase: issue == null
          ? ProductionPhase.selfCheck
          : ProductionPhase.writing,
      sentence: text.trim(),
      issue: issue,
    );
  }

  ProductionFlow confirmNatural() => phase != ProductionPhase.selfCheck
      ? this
      : ProductionFlow(
          forms: forms,
          phase: ProductionPhase.accepted,
          sentence: sentence,
        );

  ProductionFlow rejectNatural() => phase != ProductionPhase.selfCheck
      ? this
      : ProductionFlow(forms: forms, sentence: sentence);
}
