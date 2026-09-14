import 'package:content/src/corpus/cooccurrence.dart';
import 'package:content/src/corpus/corpus_index.dart';
import 'package:content/src/corpus/domain_seeds.dart';
import 'package:content/src/corpus/lexicon.dart';
import 'package:content/src/corpus/metrics.dart';
import 'package:content/src/corpus/pipeline.dart' show slotGroup;
import 'package:content/src/text/spanish_morphology.dart';

export 'package:content/src/corpus/corpus_index.dart'
    show CorpusIndex, PackageCounts;

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

  CandidateRow withThemes(List<String> themes) => CandidateRow(
    lemma: lemma,
    pos: pos,
    zipf: zipf,
    dp: dp,
    pedantryProxy: pedantryProxy,
    familySize: familySize,
    comodinLeverage: comodinLeverage,
    suggestedThemes: themes,
    score: score,
    flags: flags,
    metricsPending: metricsPending,
  );

  CandidateRow withFlags(List<String> extra) => CandidateRow(
    lemma: lemma,
    pos: pos,
    zipf: zipf,
    dp: dp,
    pedantryProxy: pedantryProxy,
    familySize: familySize,
    comodinLeverage: comodinLeverage,
    suggestedThemes: suggestedThemes,
    score: score,
    flags: [...flags, ...extra],
    metricsPending: metricsPending,
  );

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

  Map<String, Object?> toJson() => {
    'lemma': lemma,
    'pos': pos,
    'zipf': zipf,
    'dp': dp,
    'pedantry_proxy': pedantryProxy,
    'family_size': familySize,
    'comodin_leverage': comodinLeverage,
    'suggested_themes': suggestedThemes,
    'score': score,
    'flags': flags,
    'metrics_pending': metricsPending,
  };
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

/// Reads a `candidates.csv` back, for `content:shortlist`.
List<CandidateRow> parseCsv(String csv) {
  final rows = <CandidateRow>[];
  final lines = csv.split('\n');
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final fields = _splitCsvLine(line);
    if (fields.length < candidateCsvHeader.length) continue;
    rows.add(
      CandidateRow(
        lemma: fields[0],
        pos: fields[1],
        zipf: double.tryParse(fields[2]) ?? 0,
        dp: double.tryParse(fields[3]) ?? 0,
        pedantryProxy: double.tryParse(fields[4]) ?? 0,
        familySize: int.tryParse(fields[5]) ?? 0,
        comodinLeverage: double.tryParse(fields[6]) ?? 0,
        suggestedThemes: fields[7].isEmpty ? const [] : fields[7].split('|'),
        score: double.tryParse(fields[8]) ?? 0,
        flags: fields[9].isEmpty ? const [] : fields[9].split('|'),
        metricsPending: fields[10] == 'true',
      ),
    );
  }
  return rows;
}

List<String> _splitCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        buffer.write(char);
      }
    } else if (char == '"') {
      quoted = true;
    } else if (char == ',') {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// The tunable half of the pool: where each evidence gate sits.
///
/// Fixed thresholds do not survive a change of corpus — a raw share saturates,
/// and a lift threshold has to be re-tuned whenever the seed sets move — so
/// the comodín gate is a percentile of the candidates themselves and leverage
/// is the rank inside the survivor set. These are policy, not physics, which
/// is why they are a parameter and not a constant buried in the loop.
final class PoolPolicy {
  const PoolPolicy({
    this.comodinKeepShare = 0.92,
    this.abstractMinimumLift = 1.2,
    this.themeMinimumLift = 4.0,
    this.themeMinimumShare = 0.01,
    this.themeShareCap = 0.15,
  });

  /// Everything passes, for tests that exercise a mechanism rather than a
  /// threshold on a population of two.
  static const permissive = PoolPolicy(
    comodinKeepShare: 1,
    abstractMinimumLift: 0,
    themeMinimumLift: 1,
    themeMinimumShare: 0,
  );

  /// Share of the candidates with comodín evidence that survive the gate.
  final double comodinKeepShare;

  /// Abstract-vocabulary lift needed to count as communication vocabulary.
  final double abstractMinimumLift;

  /// Lift a theme's vocabulary needs before the theme is suggested.
  final double themeMinimumLift;

  /// Floor under the theme lift, so one lucky marker in a small seed set
  /// cannot manufacture a theme.
  final double themeMinimumShare;

  /// Share of the pool a single theme may own.
  final double themeShareCap;
}

/// Builds the ranked candidate pool.
///
/// Four gates run before anything is scored, so noise is dropped rather than
/// ranked:
/// 1. shape — function word, too short, inflected form, foreign spelling;
/// 2. dictionary — the lemma must be in [lexicon] and must be morphologically
///    consistent with the category the dictionary gives it;
/// 3. country attestation — pan-Hispanic is a selection criterion;
/// 4. domain — the candidate's company must be abstract, not physical.
List<CandidateRow> buildCandidatePool(
  List<PackageCounts> packages, {
  required SpanishLexicon lexicon,
  EvidenceIndex? evidence,
  EvidenceIndex? slotEvidence,
  CorpusIndex? prebuiltIndex,
  int limit = 1500,
  PoolPolicy policy = const PoolPolicy(),
}) {
  final index = prebuiltIndex ?? CorpusIndex.build(packages);
  final rows = <CandidateRow>[];

  for (final lemma in index.lemmas) {
    final spelled = index.display(lemma);
    if (spanishFunctionWords.contains(lemma)) continue;
    if (lemma.length < 4) continue;
    if (looksInflected(spelled)) continue;
    if (looksForeign(spelled)) continue;

    final dictionaryPos = lexicon.partOfSpeechFor(lemma);
    if (lexicon.isNotEmpty) {
      if (!lexicon.contains(lemma)) continue;
      if (!_inflectsConsistently(lemma, dictionaryPos)) continue;
    }

    final observed = index.countryCountsOf(lemma);
    if (observed.fold<int>(0, (a, b) => a + b) == 0) continue;

    final lemmaZipf = index.zipfOf(lemma);
    if (lemmaZipf < minCandidateZipf || lemmaZipf > maxCandidateZipf) continue;

    if (evidence != null &&
        !_isCommunicationVocabulary(evidence, lemma, policy)) {
      continue;
    }

    final dp = index.dispersionOf(lemma);
    final pos = dictionaryPos ?? guessPartOfSpeech(spelled);
    final family = index.familySizeOf(lemma);
    final proxy = index.pedantryOf(lemma);
    // The slot signal (immediate neighbours) is the substitutability test and
    // wins when it is available; the argument signal (same sentence) is the
    // topical fallback.
    final comodinLift =
        slotEvidence?.liftOf(lemma, slotGroup) ??
        evidence?.liftOf(lemma, comodinGroup) ??
        0;
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
        // Filled in once the whole population is known.
        comodinLeverage: comodinLift,
        suggestedThemes: evidence == null
            ? const []
            : _themesFor(evidence, lemma, policy),
        score: 0,
        flags: [
          if (dp > 0.45 || missingCountries > 0.6) 'regional-only',
          if (lexicon.isEmpty) 'dictionary-unverified',
          if (evidence == null) 'domain-unverified',
          'semantic-set:${index.semanticSetOf(lemma)}',
        ],
      ),
    );
  }

  final scored = evidence == null
      ? [for (final row in rows) _rescored(row, leverage: 0)]
      : _gateAndRankByComodin(rows, policy);

  final top =
      (scored..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            return byScore != 0 ? byScore : a.lemma.compareTo(b.lemma);
          }))
          .take(limit)
          .toList();
  return _capThemeShare(_flagParonyms(top), policy.themeShareCap);
}

/// Keeps the candidates that most keep the comodines' company, and turns each
/// survivor's rank in that set into its 0..1 leverage.
List<CandidateRow> _gateAndRankByComodin(
  List<CandidateRow> rows,
  PoolPolicy policy,
) {
  final withEvidence =
      [
        for (final row in rows)
          if (row.comodinLeverage > 0) row,
      ]..sort((a, b) {
        final byLift = b.comodinLeverage.compareTo(a.comodinLeverage);
        return byLift != 0 ? byLift : a.lemma.compareTo(b.lemma);
      });
  // Nothing to gate on: pass 1 found no comodín arguments at all. Gating the
  // whole pool away on missing evidence would be worse than letting it
  // through unranked.
  if (withEvidence.isEmpty) {
    return [for (final row in rows) _rescored(row, leverage: 0)];
  }
  final keep = (withEvidence.length * policy.comodinKeepShare).ceil().clamp(
    1,
    withEvidence.length,
  );
  final survivors = withEvidence.take(keep).toList();
  return [
    for (var i = 0; i < survivors.length; i++)
      _rescored(
        survivors[i],
        leverage: survivors.length == 1 ? 1 : 1 - i / (survivors.length - 1),
      ),
  ];
}

CandidateRow _rescored(CandidateRow row, {required double leverage}) =>
    CandidateRow(
      lemma: row.lemma,
      pos: row.pos,
      zipf: row.zipf,
      dp: row.dp,
      pedantryProxy: row.pedantryProxy,
      familySize: row.familySize,
      comodinLeverage: leverage,
      suggestedThemes: row.suggestedThemes,
      score: candidateScore(
        zipf: row.zipf,
        dp: row.dp,
        pedantryProxy: row.pedantryProxy,
        comodinLeverage: leverage,
        familySize: row.familySize,
      ),
      flags: row.flags,
      metricsPending: row.metricsPending,
    );

/// The dictionary says what the word is; morphology says whether this
/// particular form is the lemma of that category.
bool _inflectsConsistently(String lemma, String? dictionaryPos) {
  if (dictionaryPos == null) return true;
  final isInfinitive =
      lemma.endsWith('ar') || lemma.endsWith('er') || lemma.endsWith('ir');
  if (dictionaryPos == 'verbo') return isInfinitive;
  return true;
}

/// A candidate has to be positively abstract, not merely not-physical: most
/// concrete nouns never meet a physical marker either.
bool _isCommunicationVocabulary(
  EvidenceIndex evidence,
  String lemma,
  PoolPolicy policy,
) {
  final abstractMass = evidence.massOf(lemma, abstractGroup);
  final physicalMass = evidence.massOf(lemma, physicalGroup);
  if (abstractMass <= 0) return false;
  if (abstractMass <= physicalMass) return false;
  return evidence.liftOf(lemma, abstractGroup) >= policy.abstractMinimumLift;
}

List<String> _themesFor(
  EvidenceIndex evidence,
  String lemma,
  PoolPolicy policy,
) {
  final scored = <String, double>{};
  for (final theme in themeMarkers.keys) {
    final lift = evidence.liftOf(lemma, themeGroup(theme));
    final share = evidence.shareOf(lemma, themeGroup(theme));
    if (lift >= policy.themeMinimumLift && share >= policy.themeMinimumShare) {
      scored[theme] = lift;
    }
  }
  if (scored.isEmpty) return const [];
  final sorted = scored.entries.toList()
    ..sort((a, b) {
      final byShare = b.value.compareTo(a.value);
      return byShare != 0 ? byShare : a.key.compareTo(b.key);
    });
  // One theme, the best supported one: two were mostly noise.
  return [sorted.first.key];
}

/// No theme may own more than [cap] of the pool. The weakest holders lose it
/// and are left with no suggestion, which is more useful than a wrong one.
List<CandidateRow> _capThemeShare(List<CandidateRow> rows, double cap) {
  if (rows.isEmpty) return rows;
  final allowed = (rows.length * cap).ceil();
  final holders = <String, List<int>>{};
  for (var i = 0; i < rows.length; i++) {
    for (final theme in rows[i].suggestedThemes) {
      holders.putIfAbsent(theme, () => []).add(i);
    }
  }
  final dropped = <int, Set<String>>{};
  for (final entry in holders.entries) {
    if (entry.value.length <= allowed) continue;
    // rows are already sorted by score, so the tail is the weakest evidence.
    for (final i in entry.value.skip(allowed)) {
      dropped.putIfAbsent(i, () => <String>{}).add(entry.key);
    }
  }
  if (dropped.isEmpty) return rows;
  return [
    for (var i = 0; i < rows.length; i++)
      if (dropped.containsKey(i))
        rows[i].withThemes([
          for (final theme in rows[i].suggestedThemes)
            if (!dropped[i]!.contains(theme)) theme,
        ])
      else
        rows[i],
  ];
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
      row.withFlags([for (final n in neighbours) 'paronym-of:$n']),
    );
  }
  return result;
}

/// Top-N lemmas by total frequency, for the common-word validator.
List<String> topLemmas(List<PackageCounts> packages, {int limit = 5000}) {
  final index = CorpusIndex.build(packages);
  final sorted = index.lemmaTotals.entries.toList()
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
      suggestedThemes: const [],
      score: 0,
      flags: const ['editorial-fallback'],
      metricsPending: true,
    ),
];
