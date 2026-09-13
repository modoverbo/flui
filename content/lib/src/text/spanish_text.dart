/// Spanish-aware text helpers shared by every validator.
///
/// Everything here is deterministic and dependency free so the validators can
/// run thousands of comparisons per library pass without touching the network.
library;

const _diacritics = <String, String>{
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
  'Á': 'A',
  'É': 'E',
  'Í': 'I',
  'Ó': 'O',
  'Ú': 'U',
  'Ü': 'U',
  'à': 'a',
  'è': 'e',
  'ì': 'i',
  'ò': 'o',
  'ù': 'u',
  'â': 'a',
  'ê': 'e',
  'î': 'i',
  'ô': 'o',
  'û': 'u',
};

/// Removes Spanish diacritics but keeps `ñ`, which is a letter of its own.
String stripDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString();
}

/// Lowercase + accent-insensitive form used for every content comparison.
String foldForComparison(String input) => stripDiacritics(input).toLowerCase();

final _slugSeparators = RegExp('[^a-z0-9]+');

/// `slug` form of a lemma: folded, `ñ` mapped to `n`, separators collapsed.
String slugify(String input) {
  final folded = foldForComparison(input).replaceAll('ñ', 'n');
  return folded
      .replaceAll(_slugSeparators, '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

final _wordPattern = RegExp('[A-Za-zÀ-ÖØ-öø-ÿñÑ]+');

/// Word tokens of a Spanish text, punctuation and digits dropped.
List<String> tokenizeWords(String input) =>
    _wordPattern.allMatches(input).map((match) => match[0]!).toList();

/// Number of word tokens, used for the length caps.
int countWords(String input) => tokenizeWords(input).length;

/// Folded word tokens, the unit every similarity check works on.
List<String> foldedTokens(String input) =>
    tokenizeWords(input).map(foldForComparison).toList();

/// Word n-grams of a text, folded so that casing and accents never hide a
/// duplicate. A text shorter than [n] tokens yields a single shingle.
Set<String> shingles(String input, int n) {
  final tokens = foldedTokens(input);
  if (tokens.isEmpty) return <String>{};
  if (tokens.length <= n) return {tokens.join(' ')};
  return {
    for (var i = 0; i + n <= tokens.length; i++)
      tokens.sublist(i, i + n).join(' '),
  };
}

/// Jaccard similarity of two shingle sets; 0 when either side is empty.
double jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final intersection = a.intersection(b).length;
  final union = a.length + b.length - intersection;
  return union == 0 ? 0 : intersection / union;
}

/// The first [n] folded tokens of a text, or null when it is shorter.
String? openingNgram(String input, int n) {
  final tokens = foldedTokens(input);
  if (tokens.length < n) return null;
  return tokens.take(n).join(' ');
}

/// First [length] characters of the folded word, used for stem leakage.
String stem(String word, int length) {
  final folded = foldForComparison(word);
  return folded.length <= length ? folded : folded.substring(0, length);
}

final _infinitive = RegExp(r'(ar|er|ir)$');

/// Stem used by the leakage and `replaces` checks.
///
/// For an infinitive the thematic ending is dropped first, so `zanjar` yields
/// `zanj` and catches `zanjemos`, which a flat 5-character stem (`zanja`)
/// would miss.
String contentStem(String word, int length, {bool stripInfinitive = false}) {
  var folded = foldForComparison(word);
  if (stripInfinitive && folded.length > 4 && _infinitive.hasMatch(folded)) {
    folded = folded.substring(0, folded.length - 2);
  }
  return folded.length <= length ? folded : folded.substring(0, length);
}
