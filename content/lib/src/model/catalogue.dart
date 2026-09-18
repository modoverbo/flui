import 'package:content/src/model/word.dart';
import 'package:content/src/text/spanish_text.dart';

/// The words that reach the database, indexed by every name they answer to.
///
/// `confusions[].confused_with` is free text: the author writes the confusable
/// word the way a reader would say it, accents and all. Two things need to know
/// whether that text names a word the catalog already ships — the emitter, so
/// `word_confusions.confused_word_id` points at the real row instead of leaving
/// the app to match on a lemma string, and `confusion_symmetry`, so a pair that
/// only one of the two files declares cannot ship. Both read the same index
/// here, so a link the emitter writes and a pair the validator sees are the
/// same relation.
final class Catalogue {
  const Catalogue._(this._byName);

  /// Indexes [words] by lemma and by family member, folded for comparison.
  ///
  /// A lemma always wins over another word's family member: `improvisado` is a
  /// family member of `improvisar`, and it is also its own catalog entry, so
  /// the word that carries it as a lemma is the one a confusion names.
  factory Catalogue.of(Iterable<Word> words) {
    final byName = <String, Word>{};
    for (final word in words) {
      byName[foldForComparison(word.lemma.trim())] = word;
    }
    for (final word in words) {
      for (final member in word.family) {
        byName.putIfAbsent(foldForComparison(member.trim()), () => word);
      }
    }
    return Catalogue._(byName);
  }

  final Map<String, Word> _byName;

  /// The catalog word that goes by [name] — its lemma or one of its family
  /// members, compared without case or accents — or null when the catalog has
  /// no such word.
  Word? wordNamed(String name) => _byName[foldForComparison(name.trim())];

  /// The catalog word [confusion] points at, or null when the confusable word
  /// is not in the catalog.
  ///
  /// Never [word] itself: a confusion may name one of the word's own family
  /// members, and that is a note about the word, not a link to another entry.
  Word? confusableOf(Word word, Confusion confusion) {
    final other = wordNamed(confusion.confusedWith);
    return other == null || identical(other, word) || other.slug == word.slug
        ? null
        : other;
  }
}
