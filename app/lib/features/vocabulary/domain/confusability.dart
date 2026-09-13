import 'package:flui/features/vocabulary/domain/word.dart';

/// Paronym interference rule (docs/learning-method.md §7): [a] and [b] are
/// confusable when a confusion of either word points to the other one, by
/// `confused_word_id` or by a case-insensitive `confused_with` lemma match.
///
// TODO(content): extend this to semantic sets. Tinkham (1993, 1997) and
// Nation (2000) show that synonyms, antonyms and category mates interfere
// when learned together, while thematic or scenario clusters do not. Two
// words of the same semantic set (same synset or near-synonym group) should
// not be introduced within `SessionPlanner.interferenceDays` of each other,
// exactly like paronyms. The catalog has no semantic-set column yet, so this
// needs a `words.semantic_set` migration, seed data and pgTAP coverage
// before the rule can be written here.
bool areConfusable(Word a, Word b) {
  if (a.id == b.id) return false;
  return _pointsTo(a, b) || _pointsTo(b, a);
}

bool _pointsTo(Word from, Word to) {
  final lemma = to.lemma.trim().toLowerCase();
  return from.confusions.any(
    (confusion) =>
        confusion.confusedWordId == to.id ||
        confusion.confusedWith.trim().toLowerCase() == lemma,
  );
}
