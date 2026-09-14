import 'package:flui/features/vocabulary/domain/semantic_set_rule.dart';
import 'package:flui/features/vocabulary/domain/word.dart';

/// Paronym interference rule (docs/learning-method.md §7): [a] and [b] are
/// confusable when a confusion of either word points to the other one, by
/// `confused_word_id` or by a case-insensitive `confused_with` lemma match.
bool areConfusable(Word a, Word b) {
  if (a.id == b.id) return false;
  return _pointsTo(a, b) || _pointsTo(b, a);
}

/// Both interference rules of §7 at once: paronyms ([areConfusable]) and
/// semantic sets ([SemanticSetRule.interferes]). A candidate is introduced
/// only when neither holds against a word met in the last 7 days.
///
/// Sharing a *theme* is deliberately absent from this list: themes are a
/// thematic cluster, which Tinkham (1993, 1997) and Nation (2000) found does
/// not interfere. Otherwise choosing a theme would slow the very words the
/// theme exists to teach.
bool interferes(Word a, Word b) =>
    areConfusable(a, b) || SemanticSetRule.interferes(a, b);

bool _pointsTo(Word from, Word to) {
  final lemma = to.lemma.trim().toLowerCase();
  return from.confusions.any(
    (confusion) =>
        confusion.confusedWordId == to.id ||
        confusion.confusedWith.trim().toLowerCase() == lemma,
  );
}
