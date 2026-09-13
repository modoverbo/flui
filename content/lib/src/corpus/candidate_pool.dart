import 'package:content/src/corpus/leipzig.dart';
import 'package:content/src/corpus/metrics.dart';
import 'package:content/src/text/spanish_morphology.dart';
import 'package:content/src/text/spanish_text.dart';

/// The comodines each part of speech is supposed to displace.
const comodinesByPartOfSpeech = <String, List<String>>{
  'verbo': ['hacer', 'poner', 'tener', 'decir', 'dar', 'ver', 'sacar'],
  'sustantivo': ['cosa', 'tema', 'asunto', 'gente', 'parte'],
  'adjetivo': ['bueno', 'malo', 'grande', 'importante', 'interesante'],
  'adverbio': ['muy', 'bien', 'mucho', 'bastante'],
  'conector': ['y', 'pero', 'entonces', 'porque'],
};

/// Stem triggers that suggest a theme. Advisory only: the authoring agent or a
/// human confirms the theme when the word actually enters the catalog.
const themeStemLexicon = <String, List<String>>{
  'reuniones': ['reun', 'acuerd', 'propuest', 'plante', 'orden', 'convoc'],
  'presentaciones-oratoria': [
    'expon',
    'discurs',
    'present',
    'public',
    'audien',
  ],
  'entrevistas': ['entrevist', 'curricul', 'candidat', 'contrat', 'empleo'],
  'negociacion': ['negoci', 'acuerd', 'oferta', 'contrapart', 'condicion'],
  'liderazgo-feedback': ['lider', 'equipo', 'desempen', 'reconoc', 'orient'],
  'conflicto-desacuerdo': ['discrep', 'objet', 'rebat', 'conflict', 'disput'],
  'correos-mensajes': ['correo', 'mensaj', 'escrib', 'respond', 'redact'],
  'redaccion-ejecutiva': ['resum', 'sintet', 'concret', 'precis', 'informe'],
  'persuasion-storytelling': [
    'convenc',
    'persuad',
    'relat',
    'argument',
    'ilustr',
  ],
  'conversaciones-dificiles': [
    'aborda',
    'delicad',
    'incomod',
    'confront',
    'disculp',
  ],
  'matices-precision': ['matiz', 'precis', 'sutil', 'grad', 'atenu'],
  'conectores-estructura': [
    'ademas',
    'asimism',
    'obstante',
    'consiguient',
    'cambio',
  ],
  'paronimos': [],
  'elogio-reconocimiento': ['elogi', 'admir', 'valor', 'destac', 'merit'],
  'decir-que-no': ['rechaz', 'negar', 'declin', 'limit', 'excus'],
  'conversacion-cotidiana': ['cotidian', 'charl', 'contar', 'coment'],
};

const _defaultThemesByPartOfSpeech = <String, List<String>>{
  'verbo': ['reuniones', 'conversacion-cotidiana'],
  'sustantivo': ['redaccion-ejecutiva', 'conversacion-cotidiana'],
  'adjetivo': ['elogio-reconocimiento', 'matices-precision'],
  'adverbio': ['matices-precision'],
  'conector': ['conectores-estructura'],
};

final class CandidateRow {
  const CandidateRow({
    required this.lemma,
    required this.pos,
    required this.zipf,
    required this.dp,
    required this.pedantryProxy,
    required this.familySize,
    required this.comodinLeverage,
    required this.suggestedThemes,
    required this.score,
    required this.flags,
    this.metricsPending = false,
  });

  final String lemma;
  final String pos;
  final double zipf;
  final double dp;
  final double pedantryProxy;
  final int familySize;
  final double comodinLeverage;
  final List<String> suggestedThemes;
  final double score;
  final List<String> flags;
  final bool metricsPending;

  /// Numeric columns stay empty while metrics are pending: the toolkit never
  /// invents a frequency it did not measure.
  List<String> toCsvRow() => [
    lemma,
    pos,
    if (metricsPending) '' else zipf.toStringAsFixed(3),
    if (metricsPending) '' else dp.toStringAsFixed(3),
    if (metricsPending) '' else pedantryProxy.toStringAsFixed(3),
    if (metricsPending) '' else '$familySize',
    if (metricsPending) '' else comodinLeverage.toStringAsFixed(3),
    suggestedThemes.join('|'),
    if (metricsPending) '' else score.toStringAsFixed(4),
    flags.join('|'),
    '$metricsPending',
  ];
}

const candidateCsvHeader = <String>[
  'lemma',
  'pos',
  'zipf',
  'dp',
  'pedantry_proxy',
  'family_size',
  'comodin_leverage',
  'suggested_themes',
  'score',
  'flags',
  'metrics_pending',
];

String toCsv(List<CandidateRow> rows) {
  final buffer = StringBuffer()..writeln(candidateCsvHeader.join(','));
  for (final row in rows) {
    buffer.writeln(row.toCsvRow().map(_csvField).join(','));
  }
  return buffer.toString();
}

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// One package's word counts plus the role it plays.
final class PackageCounts {
  const PackageCounts(this.package, this.counts);

  final LeipzigPackage package;
  final Map<String, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// Builds the ranked candidate pool from the downloaded packages.
List<CandidateRow> buildCandidatePool(
  List<PackageCounts> packages, {
  int limit = 1500,
}) {
  // 1. Merge accent variants ("solucion" into "solución"), keeping whichever
  // spelling the corpus uses most, then fold every form onto a corpus-attested
  // base form.
  final globalSurface = <String, int>{};
  final spellings = <String, Map<String, int>>{};
  for (final package in packages) {
    for (final entry in package.counts.entries) {
      final surface = normalizeSurface(entry.key);
      if (surface == null) continue;
      final key = foldForComparison(surface);
      globalSurface[key] = (globalSurface[key] ?? 0) + entry.value;
      final variants = spellings.putIfAbsent(key, () => <String, int>{});
      variants[surface] = (variants[surface] ?? 0) + entry.value;
    }
  }
  String display(String key) {
    final variants = spellings[key];
    if (variants == null || variants.isEmpty) return key;
    return variants.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  final lemmaOf = <String, String>{
    for (final surface in globalSurface.keys)
      surface: surfaceToLemma(surface, globalSurface),
  };

  // 2. Per-package lemma counts.
  final perPackage = <String, Map<String, int>>{};
  final packageTotals = <String, int>{};
  for (final package in packages) {
    final counts = <String, int>{};
    var total = 0;
    for (final entry in package.counts.entries) {
      final surface = normalizeSurface(entry.key);
      if (surface == null) continue;
      final lemma = lemmaOf[foldForComparison(surface)]!;
      counts[lemma] = (counts[lemma] ?? 0) + entry.value;
      total += entry.value;
    }
    perPackage[package.package.name] = counts;
    packageTotals[package.package.name] = total;
  }

  final countryPackages = [
    for (final package in packages)
      if (package.package.role == CorpusRole.country) package,
  ];
  final formalPackages = [
    for (final package in packages)
      if (package.package.role == CorpusRole.formal) package,
  ];
  final informalPackages = [
    for (final package in packages)
      if (package.package.role == CorpusRole.informal) package,
  ];

  final totalTokens = packageTotals.values.fold(0, (a, b) => a + b);
  final lemmaTotals = <String, int>{};
  for (final counts in perPackage.values) {
    for (final entry in counts.entries) {
      lemmaTotals[entry.key] = (lemmaTotals[entry.key] ?? 0) + entry.value;
    }
  }

  // 3. Derivational family size: lemmas sharing a 5-character stem.
  final familyByStem = <String, int>{};
  for (final lemma in lemmaTotals.keys) {
    if (lemma.length < 5) continue;
    final key = stem(lemma, 5);
    familyByStem[key] = (familyByStem[key] ?? 0) + 1;
  }

  double perMillion(List<PackageCounts> group, String lemma) {
    var frequency = 0;
    var total = 0;
    for (final package in group) {
      frequency += perPackage[package.package.name]![lemma] ?? 0;
      total += packageTotals[package.package.name]!;
    }
    return total == 0 ? 0 : frequency / total * 1e6;
  }

  final zipfByLemma = <String, double>{
    for (final entry in lemmaTotals.entries)
      entry.key: zipf(frequency: entry.value, totalTokens: totalTokens),
  };

  double leverageOf(String lemma, String pos) {
    final comodines = comodinesByPartOfSpeech[pos] ?? const [];
    var best = 0.0;
    for (final comodin in comodines) {
      final comodinZipf = zipfByLemma[comodin];
      if (comodinZipf == null) continue;
      final gap = (comodinZipf - (zipfByLemma[lemma] ?? 0)) / 3;
      if (gap > best) best = gap;
    }
    return best.clamp(0.0, 1.0);
  }

  List<String> themesFor(String lemma, String pos) {
    final themes = <String>{};
    for (final entry in themeStemLexicon.entries) {
      for (final trigger in entry.value) {
        if (lemma.startsWith(trigger)) themes.add(entry.key);
      }
    }
    if (themes.isEmpty) {
      themes.addAll(_defaultThemesByPartOfSpeech[pos] ?? const []);
    }
    return themes.toList()..sort();
  }

  // 4. Candidate rows, pre-filtered to plausible content words.
  final rows = <CandidateRow>[];
  for (final entry in lemmaTotals.entries) {
    final lemma = entry.key;
    final spelled = display(lemma);
    if (spanishFunctionWords.contains(lemma)) continue;
    if (lemma.length < 4) continue;
    if (looksInflected(spelled)) continue;
    if (looksForeign(spelled)) continue;
    final lemmaZipf = zipfByLemma[lemma]!;
    if (lemmaZipf < minCandidateZipf || lemmaZipf > maxCandidateZipf) continue;

    final observed = [
      for (final package in countryPackages)
        perPackage[package.package.name]![lemma] ?? 0,
    ];
    // Pan-Hispanic is a selection criterion: a form no country subcorpus
    // attests cannot be judged, and is usually an extraction artefact.
    if (observed.fold<int>(0, (a, b) => a + b) == 0) continue;
    final sizes = [
      for (final package in countryPackages)
        packageTotals[package.package.name]!,
    ];
    final dp = griesDp(observed: observed, partSizes: sizes);
    final pos = guessPartOfSpeech(lemma);
    final family = (familyByStem[stem(lemma, 5)] ?? 1) - 1;
    final proxy = pedantryProxy(
      formalPerMillion: perMillion(formalPackages, lemma),
      informalPerMillion: perMillion(informalPackages, lemma),
    );
    final leverage = leverageOf(lemma, pos);
    final missingCountries =
        observed.where((value) => value == 0).length /
        (observed.isEmpty ? 1 : observed.length);

    rows.add(
      CandidateRow(
        lemma: spelled,
        pos: pos,
        zipf: lemmaZipf,
        dp: dp,
        pedantryProxy: proxy,
        familySize: family,
        comodinLeverage: leverage,
        suggestedThemes: themesFor(lemma, pos),
        score: candidateScore(
          zipf: lemmaZipf,
          dp: dp,
          pedantryProxy: proxy,
          comodinLeverage: leverage,
          familySize: family,
        ),
        flags: [
          if (dp > 0.45 || missingCountries > 0.6) 'regional-only',
          'semantic-set:${stem(lemma, 5)}',
        ],
      ),
    );
  }

  rows.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.lemma.compareTo(b.lemma);
  });
  final top = rows.take(limit).toList();
  return _flagParonyms(top);
}

/// Adds `paronym-of:<lemma>` for near neighbours inside the pool.
List<CandidateRow> _flagParonyms(List<CandidateRow> rows) {
  final buckets = <int, List<CandidateRow>>{};
  for (final row in rows) {
    buckets.putIfAbsent(row.lemma.length, () => []).add(row);
  }
  final result = <CandidateRow>[];
  for (final row in rows) {
    final neighbours = <String>[];
    for (
      var length = row.lemma.length - 1;
      length <= row.lemma.length + 1;
      length++
    ) {
      for (final other in buckets[length] ?? const <CandidateRow>[]) {
        if (other.lemma == row.lemma) continue;
        if (other.lemma[0] != row.lemma[0] &&
            other.lemma[other.lemma.length - 1] !=
                row.lemma[row.lemma.length - 1]) {
          continue;
        }
        if (editDistance(row.lemma, other.lemma) <= 2) {
          neighbours.add(other.lemma);
        }
        if (neighbours.length == 3) break;
      }
      if (neighbours.length == 3) break;
    }
    result.add(
      CandidateRow(
        lemma: row.lemma,
        pos: row.pos,
        zipf: row.zipf,
        dp: row.dp,
        pedantryProxy: row.pedantryProxy,
        familySize: row.familySize,
        comodinLeverage: row.comodinLeverage,
        suggestedThemes: row.suggestedThemes,
        score: row.score,
        flags: [
          ...row.flags,
          for (final neighbour in neighbours) 'paronym-of:$neighbour',
        ],
      ),
    );
  }
  return result;
}

/// Top-N lemmas by total frequency, for the common-word validator.
List<String> topLemmas(List<PackageCounts> packages, {int limit = 5000}) {
  final totals = <String, int>{};
  for (final package in packages) {
    for (final entry in package.counts.entries) {
      final surface = normalizeSurface(entry.key);
      if (surface == null) continue;
      final key = foldForComparison(surface);
      totals[key] = (totals[key] ?? 0) + entry.value;
    }
  }
  final lemmaTotals = <String, int>{};
  for (final entry in totals.entries) {
    final lemma = surfaceToLemma(entry.key, totals);
    lemmaTotals[lemma] = (lemmaTotals[lemma] ?? 0) + entry.value;
  }
  final sorted = lemmaTotals.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return [for (final entry in sorted.take(limit)) entry.key];
}

/// Rows built from the editorial fallback list, with no invented numbers.
List<CandidateRow> fallbackPool(List<String> lemmas) => [
  for (final lemma in lemmas)
    CandidateRow(
      lemma: lemma,
      pos: guessPartOfSpeech(lemma),
      zipf: 0,
      dp: 0,
      pedantryProxy: 0,
      familySize: 0,
      comodinLeverage: 0,
      suggestedThemes: themeStemLexicon.entries
          .where((e) => e.value.any(lemma.startsWith))
          .map((e) => e.key)
          .toList(),
      score: 0,
      flags: const ['editorial-fallback'],
      metricsPending: true,
    ),
];
