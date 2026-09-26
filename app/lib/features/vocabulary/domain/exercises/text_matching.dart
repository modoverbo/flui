/// Text helpers for typed answers: normalization and edit distance.
library;

const _diacritics = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

final _whitespace = RegExp(r'\s+');
final _letters = RegExp(r'[\p{L}\p{M}]+', unicode: true);

/// Lowercase, trimmed, without diacritics and with single spaces.
///
/// "ñ" becomes "n" too, so a keyboard without it never blocks an answer.
String normalizeText(String input) {
  final lower = input.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString().replaceAll(_whitespace, ' ');
}

/// Normalized words of [text], ignoring punctuation.
List<String> wordTokens(String text) => [
  for (final match in _letters.allMatches(text)) normalizeText(match[0]!),
];

/// Letter runs of [text] with their positions in the original string.
Iterable<({String text, int start, int end})> wordSpans(String text) => _letters
    .allMatches(text)
    .map((m) => (text: m[0]!, start: m.start, end: m.end));

/// Levenshtein edit distance (insertions, deletions, substitutions).
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + cost;
      var best = deletion < insertion ? deletion : insertion;
      if (substitution < best) best = substitution;
      current[j] = best;
    }
    previous = current;
  }
  return previous[b.length];
}
