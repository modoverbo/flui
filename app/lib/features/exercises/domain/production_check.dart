import 'package:flui/features/exercises/domain/text_matching.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:meta/meta.dart';

enum ProductionIssue {
  tooShort,
  missingWord,

  /// Four tokens, but not four different ones ("uso uso uso perspicaz").
  repeated,

  /// The model sentence typed back. Copying is not producing.
  copiedModel,
}

/// What the user confirms about their own sentence. flui cannot judge a
/// sentence, so it asks the user to judge it against named criteria instead
/// of a single "¿Suena natural?" that is easy to wave through.
enum ProductionRubric { meaning, natural, fits }

/// "Úsala": the user's own sentence must use the word (any form), have at
/// least [minWords] words and [minDistinctWords] different ones, and not be
/// the model sentence typed back. Meaning and register are self-checked
/// against [ProductionRubric].
abstract final class ProductionCheck {
  static const minWords = 4;
  static const minDistinctWords = 4;

  static ProductionIssue? validate(
    String sentence,
    WordForms forms, {
    String? modelSentence,
  }) {
    final tokens = wordTokens(sentence);
    if (tokens.length < minWords) return ProductionIssue.tooShort;
    if (tokens.toSet().length < minDistinctWords) {
      return ProductionIssue.repeated;
    }
    if (!forms.appearsIn(sentence)) return ProductionIssue.missingWord;
    if (modelSentence != null &&
        wordTokens(modelSentence).join(' ') == tokens.join(' ')) {
      return ProductionIssue.copiedModel;
    }
    return null;
  }
}

enum ProductionPhase { writing, selfCheck, accepted }

/// Writing → the model sentence plus the rubric → accepted
/// (`production_done = true`). Every rubric item has to be ticked, so the
/// user reads their sentence against each criterion instead of tapping once.
@immutable
final class ProductionFlow {
  const new({
    required this.forms,
    this.phase = ProductionPhase.writing,
    this.sentence = '',
    this.issue,
    this.confirmed = const {},
    this.modelSentence,
  });

  final WordForms forms;
  final ProductionPhase phase;
  final String sentence;
  final ProductionIssue? issue;

  /// Rubric items the user has ticked in the self-check.
  final Set<ProductionRubric> confirmed;

  /// A sentence that works, shown after the attempt as a comparison. It is
  /// never scored against: it is there to read, not to copy.
  final String? modelSentence;

  bool get isAccepted => phase == ProductionPhase.accepted;

  bool get isRubricComplete =>
      confirmed.length == ProductionRubric.values.length;

  ProductionFlow submit(String text) {
    if (phase != ProductionPhase.writing) return this;
    final issue = ProductionCheck.validate(
      text,
      forms,
      modelSentence: modelSentence,
    );
    return _copy(
      phase: issue == null
          ? ProductionPhase.selfCheck
          : ProductionPhase.writing,
      sentence: text.trim(),
      issue: issue,
      keepIssue: true,
    );
  }

  /// Ticks or unticks one rubric item.
  ProductionFlow toggle(ProductionRubric item) {
    if (phase != ProductionPhase.selfCheck) return this;
    return _copy(
      confirmed: {
        for (final current in confirmed)
          if (current != item) current,
        if (!confirmed.contains(item)) item,
      },
    );
  }

  /// Accepts only once every rubric item is ticked.
  ProductionFlow confirmNatural() =>
      phase != ProductionPhase.selfCheck || !isRubricComplete
      ? this
      : _copy(phase: ProductionPhase.accepted);

  ProductionFlow rejectNatural() => phase != ProductionPhase.selfCheck
      ? this
      : _copy(phase: ProductionPhase.writing, confirmed: const {});

  ProductionFlow _copy({
    ProductionPhase? phase,
    String? sentence,
    ProductionIssue? issue,
    bool keepIssue = false,
    Set<ProductionRubric>? confirmed,
  }) => ProductionFlow(
    forms: forms,
    phase: phase ?? this.phase,
    sentence: sentence ?? this.sentence,
    issue: keepIssue ? issue : null,
    confirmed: confirmed ?? this.confirmed,
    modelSentence: modelSentence,
  );
}
