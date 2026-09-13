import 'package:flui/features/vocabulary/domain/word.dart';

/// Paronym interference rule (docs/learning-method.md §7): [a] and [b] are
/// confusable when a confusion of either word points to the other one, by
/// `confused_word_id` or by a case-insensitive `confused_with` lemma match.
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
