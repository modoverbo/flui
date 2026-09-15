import 'package:flui/features/exercises/domain/text_matching.dart';
import 'package:meta/meta.dart';

/// The written forms that count as using a word.
///
/// Spanish inflects heavily ("plantear" → "planteé", "plantearlo"), so a
/// token matches when it is a known form (lemma, family, the inflections
/// used in the word's exercises) or extends the word's stem.
@immutable
final class WordForms {
  const new({
    required this.lemma,
    required this.isVerb,
    this.extraForms = const [],
  });

  /// Stems shorter than this match too many unrelated words.
  static const minStemLength = 4;

  final String lemma;
  final bool isVerb;

  /// Family words and known inflections.
  final List<String> extraForms;

  bool get _isPhrase => normalizeText(lemma).contains(' ');

  /// Normalized lemma and extra forms.
  Set<String> get knownForms =>
      {normalizeText(lemma), for (final form in extraForms) normalizeText(form)}
        ..remove('');

  /// Verbs drop the infinitive ending; adjectives and nouns drop a final
  /// vowel or "z" (perspicaz → perspicaces).
  ///
  /// A pronominal infinitive carries the pronoun on the lemma but never on
  /// the inflected form ("extenderse" is written "me extendí"), so the "se"
  /// comes off before the ending does.
  String get stem {
    var base = normalizeText(lemma);
    if (_isPhrase || base.length <= minStemLength) return base;
    if (isVerb) {
      const endings = ['ar', 'er', 'ir'];
      if (base.endsWith('se')) base = base.substring(0, base.length - 2);
      return endings.any(base.endsWith)
          ? base.substring(0, base.length - 2)
          : base;
    }
    const finals = ['a', 'e', 'o', 'z'];
    return finals.any(base.endsWith)
        ? base.substring(0, base.length - 1)
        : base;
  }

  /// Whether a single typed word is a form of this word.
  bool matchesToken(String token) {
    final normalized = normalizeText(token);
    if (normalized.isEmpty) return false;
    if (knownForms.contains(normalized)) return true;
    final stem = this.stem;
    return !_isPhrase &&
        stem.length >= minStemLength &&
        normalized.length > stem.length &&
        normalized.startsWith(stem);
  }

  /// Whether [sentence] uses this word in any form.
  bool appearsIn(String sentence) {
    if (_isPhrase) {
      return ' ${wordTokens(sentence).join(' ')} '.contains(
        ' ${normalizeText(lemma)} ',
      );
    }
    return wordTokens(sentence).any(matchesToken);
  }

  /// Position of the first form of this word in [sentence], if any.
  ({int start, int end})? findIn(String sentence) {
    if (_isPhrase) {
      final index = sentence.toLowerCase().indexOf(lemma.toLowerCase());
      return index < 0 ? null : (start: index, end: index + lemma.length);
    }
    for (final span in wordSpans(sentence)) {
      if (matchesToken(span.text)) return (start: span.start, end: span.end);
    }
    return null;
  }
}
