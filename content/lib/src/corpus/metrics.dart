import 'dart:math' as math;

import 'package:content/src/text/spanish_text.dart';

/// Zipf value: log10 of the frequency per billion tokens.
double zipf({required int frequency, required int totalTokens}) {
  if (frequency <= 0 || totalTokens <= 0) return 0;
  return math.log(frequency / totalTokens * 1e9) / math.ln10;
}

/// Gries' deviation of proportions across corpus parts.
///
/// 0 = spread exactly like the corpus, 1 = confined to one part. Computed as
/// `0.5 * Σ |observed_i / observed_total − size_i / size_total|`.
double griesDp({required List<num> observed, required List<num> partSizes}) {
  final totalObserved = observed.fold<num>(0, (a, b) => a + b);
  final totalSize = partSizes.fold<num>(0, (a, b) => a + b);
  if (totalObserved <= 0 || totalSize <= 0) return 0;
  var sum = 0.0;
  for (var i = 0; i < observed.length; i++) {
    final o = observed[i] / totalObserved;
    final e = partSizes[i] / totalSize;
    sum += (o - e).abs();
  }
  return sum / 2;
}

const _connectors = <String>{
  'asimismo',
  'además',
  'ademas',
  'sinembargo',
  'nobstante',
  'entonces',
  'asíque',
  'porende',
  'portanto',
  'enconcreto',
  'esdecir',
  'porcierto',
  'encambio',
  'aunasí',
  'pues',
  'luego',
  'mientras',
  'salvo',
  'incluso',
  'apenas',
  'siquiera',
};

final _adjectiveEndings = <String>[
  'oso',
  'osa',
  'ivo',
  'iva',
  'ante',
  'ente',
  'az',
  'al',
  'il',
  'ico',
  'ica',
  'able',
  'ible',
  'udo',
  'uda',
];

/// Frequent words that end like an infinitive but are not verbs. Without them
/// "carácter" and "popular" would be tagged `verbo`.
const _partOfSpeechExceptions = <String, String>{
  'caracter': 'sustantivo',
  'mujer': 'sustantivo',
  'taller': 'sustantivo',
  'placer': 'sustantivo',
  'lugar': 'sustantivo',
  'hogar': 'sustantivo',
  'azucar': 'sustantivo',
  'altar': 'sustantivo',
  'bazar': 'sustantivo',
  'collar': 'sustantivo',
  'dolar': 'sustantivo',
  'titular': 'sustantivo',
  'celular': 'sustantivo',
  'ejemplar': 'sustantivo',
  'ayer': 'adverbio',
  'popular': 'adjetivo',
  'particular': 'adjetivo',
  'familiar': 'adjetivo',
  'similar': 'adjetivo',
  'regular': 'adjetivo',
  'militar': 'adjetivo',
  'escolar': 'adjetivo',
  'singular': 'adjetivo',
  'circular': 'adjetivo',
  'peculiar': 'adjetivo',
  'auxiliar': 'adjetivo',
  'vulgar': 'adjetivo',
  'solar': 'adjetivo',
  'polar': 'adjetivo',
  'espectacular': 'adjetivo',
};

/// Endings that only a conjugated form carries. A candidate that matches one
/// is an inflection, not a lemma, and never reaches the pool.
final _inflectedEndings = <RegExp>[
  RegExp(r'(amos|emos|imos)$'),
  RegExp(r'(aron|ieron|eron)$'),
  RegExp(r'(aba|abas|aban|abamos)$'),
  RegExp(r'(ia|ias|ian|iamos)$'),
  RegExp(r'(ando|iendo|yendo)$'),
  RegExp(r'(aste|iste|asteis|isteis)$'),
  RegExp(r'(ara|aran|ase|asen|iera|ieran|iese|iesen)$'),
  RegExp(r'(are|aria|arian|eria|erian|iria|irian)$'),
  RegExp(r'(aran|eran|iran|are|ere|ire)$'),
  RegExp('^(fuer|fues|hubier|hubies|estuvier)'),
  RegExp(r'(isimo|isima|isimos|isimas)$'),
];

/// Clitic pronouns that glue onto a verb form.
final _clitic = RegExp(r'(me|te|se|nos|os|lo|la|le|los|las|les)$');

/// Letter patterns Spanish orthography does not produce. Cheap way to keep
/// English tokens out of a pool of Spanish candidates.
final _foreignPatterns = <RegExp>[
  RegExp('[kw]'),
  // Spanish doubles only c, l, n and r, and never starts a word with s plus a
  // consonant: it prothesizes an e ("escáner", not "scanner").
  RegExp('(ss|tt|ff|mm|pp|bb|gg|dd|ck|sh|ph|th|zz)'),
  RegExp('^s[cpt]'),
  RegExp(r'[bcfgmptv]$'),
];

/// Whether a token is very unlikely to be a Spanish word.
bool looksForeign(String surface) {
  final folded = foldForComparison(surface);
  return _foreignPatterns.any((pattern) => pattern.hasMatch(folded));
}

/// An infinitive or gerund with a clitic glued on: `dedicarme`, `llamarnos`.
final _cliticForm = RegExp(
  r'(ar|er|ir|ando|iendo)(me|te|se|nos|os|lo|la|le|los|las|les)$',
);

/// Participles, which are inflections even when they read as adjectives.
final _participle = RegExp(r'(ado|ada|ados|adas|ido|ida|idos|idas)$');

/// Whether a surface form is a conjugated or otherwise inflected form rather
/// than a lemma. Deliberately generous: a candidate pool with a false negative
/// wastes an author's time, a false positive only drops one row out of
/// thousands.
bool looksInflected(String surface) {
  final lower = surface.toLowerCase();
  final folded = foldForComparison(surface);
  if (folded.length < 5) return false;
  // A lemma is singular; Spanish lemmas ending in -s are rare enough to skip.
  if (folded.endsWith('s') && !_cliticForm.hasMatch(folded)) return true;
  // 1st person preterite and other accented final vowels.
  if (RegExp(r'[áéíóú]$').hasMatch(lower)) return true;
  if (_cliticForm.hasMatch(folded)) return true;
  if (_participle.hasMatch(folded)) return true;
  // An accented clitic imperative: imagínese, infórmate.
  if (RegExp('[áéíóú]').hasMatch(lower) && _clitic.hasMatch(folded)) {
    return true;
  }
  if (folded.endsWith('ar') || folded.endsWith('er') || folded.endsWith('ir')) {
    return false;
  }
  return _inflectedEndings.any((pattern) => pattern.hasMatch(folded));
}

/// Cheap part-of-speech guess from Spanish morphology.
///
/// Good enough to rank candidates; a human or an authoring agent confirms it
/// when the word actually enters the catalog.
String guessPartOfSpeech(String lemma) {
  final folded = foldForComparison(lemma);
  final exception = _partOfSpeechExceptions[folded];
  if (exception != null) return exception;
  if (_connectors.contains(folded)) return 'conector';
  if (folded.endsWith('mente')) return 'adverbio';
  if (folded.endsWith('ar') || folded.endsWith('er') || folded.endsWith('ir')) {
    // -ar is also a frequent adjective ending (familiar, popular): verbs win
    // only when the stem is long enough to be an infinitive.
    if (folded.length > 4) return 'verbo';
  }
  for (final ending in _adjectiveEndings) {
    if (folded.endsWith(ending)) return 'adjetivo';
  }
  return 'sustantivo';
}

final _lettersOnly = RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿñÑ]+$');

/// Corpus token to a comparable surface form, or null when it is not a word.
String? normalizeSurface(String token) {
  final trimmed = token.replaceAll(
    RegExp(r'^[^A-Za-zÀ-ÖØ-öø-ÿñÑ]+|[^A-Za-zÀ-ÖØ-öø-ÿñÑ]+$'),
    '',
  );
  if (!_lettersOnly.hasMatch(trimmed)) return null;
  final lower = trimmed.toLowerCase();
  if (lower.length < 3) return null;
  return lower;
}

const _inflectionEndings = <(String, String)>[
  // Spanish z/c plural alternation: matices -> matiz, veces -> vez.
  ('ces', 'z'),
  ('es', ''),
  ('s', ''),
  ('ó', 'ar'),
  ('o', 'ar'),
  ('a', 'ar'),
  ('an', 'ar'),
  ('amos', 'ar'),
  ('emos', 'ar'),
  ('emos', 'er'),
  ('imos', 'ir'),
  ('aron', 'ar'),
  ('ieron', 'er'),
  ('ieron', 'ir'),
  ('aban', 'ar'),
  ('aste', 'ar'),
  ('iste', 'er'),
  ('e', 'ar'),
  ('e', 'ir'),
  ('en', 'ar'),
  ('en', 'ir'),
  ('a', 'er'),
  ('an', 'er'),
  ('a', 'ir'),
  ('an', 'ir'),
  ('o', 'er'),
  ('o', 'ir'),
  ('aba', 'ar'),
  ('ando', 'ar'),
  ('ado', 'ar'),
  ('ada', 'ar'),
  ('e', 'er'),
  ('en', 'er'),
  ('ió', 'ir'),
  ('ieron', 'er'),
  ('iendo', 'er'),
  ('ido', 'ir'),
  ('ido', 'er'),
  ('ida', 'er'),
  ('idos', 'er'),
  ('idas', 'er'),
  ('ía', 'er'),
  ('ían', 'er'),
];

/// Maps a surface form onto a base form that the corpus itself attests.
///
/// Built from the data plus a handful of Spanish rules, which is the
/// pragmatic alternative to bundling a tagger: spaCy's Spanish models are
/// GPL-3.0 and cannot ship with flui.
String surfaceToLemma(String surface, Map<String, int> corpusFrequencies) {
  final own = corpusFrequencies[surface] ?? 0;
  var best = surface;
  var bestFrequency = own;
  var bestInfinitive = '';
  var bestInfinitiveFrequency = 0;

  for (final (suffix, replacement) in _inflectionEndings) {
    if (!surface.endsWith(suffix)) continue;
    final stem = surface.substring(0, surface.length - suffix.length);
    for (final candidateStem in _spellingVariants(stem)) {
      final base = candidateStem + replacement;
      if (base.length < 3 || base == surface) continue;
      final frequency = corpusFrequencies[base] ?? 0;
      if (frequency == 0) continue;
      // An attested infinitive is the lemma even when the conjugated form is
      // more frequent: "opina" belongs to "opinar", not the other way round.
      if (_infinitiveEndings.contains(replacement) &&
          frequency > bestInfinitiveFrequency) {
        bestInfinitive = base;
        bestInfinitiveFrequency = frequency;
      }
      // Otherwise only fold onto a base the corpus shows is the dominant form.
      if (frequency > bestFrequency && frequency > own) {
        best = base;
        bestFrequency = frequency;
      }
    }
  }
  return bestInfinitive.isNotEmpty ? bestInfinitive : best;
}

const _infinitiveEndings = {'ar', 'er', 'ir'};

/// Stems that differ from the surface only by a Spanish spelling alternation:
/// `impliqu` also stands for `implic`, `dirij` for `dirig`.
List<String> _spellingVariants(String stem) {
  if (stem.endsWith('qu')) {
    return [stem, '${stem.substring(0, stem.length - 2)}c'];
  }
  if (stem.endsWith('j')) {
    return [stem, '${stem.substring(0, stem.length - 1)}g'];
  }
  if (stem.endsWith('gu')) {
    return [stem, stem.substring(0, stem.length - 1)];
  }
  if (stem.endsWith('c')) {
    return [stem, '${stem.substring(0, stem.length - 1)}qu'];
  }
  return [stem];
}

/// Written-vs-web proxy for "does this sound bookish".
///
/// Leipzig has no Spanish spoken corpus, so the proxy contrasts the formal
/// registers it does have (news, wikipedia) with the open web.
double pedantryProxy({
  required double formalPerMillion,
  required double informalPerMillion,
}) {
  if (formalPerMillion <= 0 && informalPerMillion <= 0) return 0.5;
  final ratio = math.log((formalPerMillion + 0.1) / (informalPerMillion + 0.1));
  return 1 / (1 + math.exp(-ratio / 2));
}

/// The Zipf band a flui word lives in: recognized but rarely produced.
///
/// Calibrated against the eight hand-written seed words, which are the
/// product's own ground truth. Measured over the 21 Leipzig packages they span
/// 2.87 (perspicaz) to 5.21 (plantear), so the preference is a plateau, not a
/// point: everything inside the band is equally welcome and the score only
/// falls off outside it.
const idealZipfLow = 3.0;
const idealZipfHigh = 5.3;

/// Midpoint of the band, for callers that need a single number.
const double idealZipf = (idealZipfLow + idealZipfHigh) / 2;

/// How fast the preference decays outside the band, in Zipf units.
const zipfSpread = 0.6;

/// Zipf window a candidate must fall inside at all.
const minCandidateZipf = 2.5;
const maxCandidateZipf = 6.0;

/// Above this the word reads as bookish and the score starts to suffer.
///
/// flui deliberately teaches words that are *more* written than the open web
/// average, so moderate values carry no penalty at all.
const pedantryTolerance = 0.75;

/// Ranking score in 0..1.
double candidateScore({
  required double zipf,
  required double dp,
  required double pedantryProxy,
  required double comodinLeverage,
  required int familySize,
}) {
  final distance = zipf < idealZipfLow
      ? idealZipfLow - zipf
      : (zipf > idealZipfHigh ? zipf - idealZipfHigh : 0.0);
  final frequencyFit = math.exp(
    -math.pow(distance, 2) / (2 * zipfSpread * zipfSpread),
  );
  final spread = (1 - dp).clamp(0.0, 1.0);
  final plainness = pedantryProxy <= pedantryTolerance
      ? 1.0
      : (1 - (pedantryProxy - pedantryTolerance) / (1 - pedantryTolerance))
            .clamp(0.0, 1.0);
  final family = (familySize / 4).clamp(0.0, 1.0);
  final score =
      0.35 * frequencyFit +
      0.30 * spread +
      0.15 * plainness +
      0.12 * comodinLeverage.clamp(0.0, 1.0) +
      0.08 * family;
  return score.clamp(0.0, 1.0);
}

/// Levenshtein distance, used for the paronym flag.
int editDistance(String a, String b) {
  final previous = List<int>.generate(b.length + 1, (i) => i);
  final current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    previous.setAll(0, current);
  }
  return previous[b.length];
}
