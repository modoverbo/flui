import 'package:flui/features/vocabulary/domain/word.dart';

/// Semantic-set interference rule (docs/learning-method.md §7), the sibling of
/// the paronym rule in `confusability.dart`.
///
/// Tinkham (1993, 1997) and Nation (2000) found that words presented as a
/// **semantic set** — synonyms, antonyms or category mates — are learned more
/// slowly than the same words presented apart, because the shared meaning
/// makes the items compete at retrieval. The same research found **thematic**
/// or scenario clusters harmless, which is precisely why a flui *theme*
/// ("Reuniones", "Entrevistas") is not a semantic set: a theme groups words by
/// the situation you use them in, never by the meaning they share.
///
/// So `words.semantic_set_id` marks the groups that must stay apart, and two
/// words of one group are never introduced within [interferenceDays] of each
/// other, exactly like paronyms.
abstract final class SemanticSetRule {
  /// The same 7-day window the paronym rule uses
  /// (`SessionPlanner.interferenceDays`).
  static const interferenceDays = 7;

  /// Whether [a] and [b] belong to the same semantic set.
  static bool interferes(Word a, Word b) {
    if (a.id == b.id) return false;
    final left = _setOf(a);
    return left != null && left == _setOf(b);
  }

  /// The set id, or `null` when the word carries none. A blank string is not a
  /// set: content that forgot to fill the field must not glue words together.
  static String? _setOf(Word word) {
    final id = word.semanticSetId?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }
}
