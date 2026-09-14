import 'package:content/src/corpus/leipzig.dart';
import 'package:content/src/corpus/metrics.dart';
import 'package:content/src/text/spanish_text.dart';

/// One package's word counts plus the role it plays.
final class PackageCounts {
  const PackageCounts(this.package, this.counts);

  final LeipzigPackage package;
  final Map<String, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// Everything the pool and `content:metrics` both need: per-package lemma
/// counts, the dominant spelling of each lemma, and the derived measures.
///
/// Built once from the downloaded packages so a metric printed for a single
/// lemma is computed exactly the way the CSV computes it.
final class CorpusIndex {
  CorpusIndex._({
    required this.lemmaKeys,
    required this.perPackage,
    required this.packageTotals,
    required this.lemmaTotals,
    required this.countryPackages,
    required this.formalPackages,
    required this.informalPackages,
    required this.totalTokens,
    required Map<String, String> display,
    required Map<String, int> familyByStem,
    // ignore: prefer_initializing_formals, the fields are private.
  }) : _display = display,
       // ignore: prefer_initializing_formals, the fields are private.
       _familyByStem = familyByStem;

  factory CorpusIndex.build(List<PackageCounts> packages) {
    // Merge accent variants ("solucion" into "solución"), keeping whichever
    // spelling the corpus uses most, then fold every form onto a
    // corpus-attested base form.
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
    final lemmaOf = <String, String>{
      for (final surface in globalSurface.keys)
        surface: surfaceToLemma(surface, globalSurface),
    };

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

    final lemmaTotals = <String, int>{};
    for (final counts in perPackage.values) {
      for (final entry in counts.entries) {
        lemmaTotals[entry.key] = (lemmaTotals[entry.key] ?? 0) + entry.value;
      }
    }

    final familyByStem = <String, int>{};
    for (final lemma in lemmaTotals.keys) {
      if (lemma.length < 5) continue;
      final key = stem(lemma, 5);
      familyByStem[key] = (familyByStem[key] ?? 0) + 1;
    }

    final display = <String, String>{
      for (final entry in spellings.entries)
        entry.key: entry.value.entries
            .reduce((a, b) => b.value > a.value ? b : a)
            .key,
    };

    return CorpusIndex._(
      lemmaKeys: lemmaOf,
      perPackage: perPackage,
      packageTotals: packageTotals,
      lemmaTotals: lemmaTotals,
      countryPackages: [
        for (final p in packages)
          if (p.package.role == CorpusRole.country) p,
      ],
      formalPackages: [
        for (final p in packages)
          if (p.package.role == CorpusRole.formal) p,
      ],
      informalPackages: [
        for (final p in packages)
          if (p.package.role == CorpusRole.informal) p,
      ],
      totalTokens: packageTotals.values.fold(0, (a, b) => a + b),
      display: display,
      familyByStem: familyByStem,
    );
  }

  /// Folded surface form to the lemma key the index counts it under.
  final Map<String, String> lemmaKeys;

  final Map<String, Map<String, int>> perPackage;
  final Map<String, int> packageTotals;
  final Map<String, int> lemmaTotals;
  final List<PackageCounts> countryPackages;
  final List<PackageCounts> formalPackages;
  final List<PackageCounts> informalPackages;
  final int totalTokens;
  final Map<String, String> _display;
  final Map<String, int> _familyByStem;

  Iterable<String> get lemmas => lemmaTotals.keys;

  /// The lemma key a folded surface form belongs to, or the form itself when
  /// the corpus never saw it.
  String lemmaKeyOf(String foldedSurface) =>
      lemmaKeys[foldedSurface] ?? foldedSurface;

  /// The spelling the corpus prefers for a folded lemma.
  String display(String lemma) => _display[lemma] ?? lemma;

  bool contains(String lemma) =>
      lemmaTotals.containsKey(foldForComparison(lemma));

  int frequencyOf(String lemma) => lemmaTotals[foldForComparison(lemma)] ?? 0;

  double zipfOf(String lemma) =>
      zipf(frequency: frequencyOf(lemma), totalTokens: totalTokens);

  /// Occurrences per country subcorpus, in package order.
  List<int> countryCountsOf(String lemma) {
    final key = foldForComparison(lemma);
    return [
      for (final package in countryPackages)
        perPackage[package.package.name]![key] ?? 0,
    ];
  }

  List<int> get countrySizes => [
    for (final package in countryPackages) packageTotals[package.package.name]!,
  ];

  List<String> get countryCodes => [
    for (final package in countryPackages) package.package.country ?? '??',
  ];

  double dispersionOf(String lemma) =>
      griesDp(observed: countryCountsOf(lemma), partSizes: countrySizes);

  double _perMillion(List<PackageCounts> group, String lemma) {
    final key = foldForComparison(lemma);
    var frequency = 0;
    var total = 0;
    for (final package in group) {
      frequency += perPackage[package.package.name]![key] ?? 0;
      total += packageTotals[package.package.name]!;
    }
    return total == 0 ? 0 : frequency / total * 1e6;
  }

  double formalPerMillionOf(String lemma) => _perMillion(formalPackages, lemma);

  double informalPerMillionOf(String lemma) =>
      _perMillion(informalPackages, lemma);

  double pedantryOf(String lemma) => pedantryProxy(
    formalPerMillion: formalPerMillionOf(lemma),
    informalPerMillion: informalPerMillionOf(lemma),
  );

  /// Other lemmas sharing the same 5-character stem.
  int familySizeOf(String lemma) {
    final key = foldForComparison(lemma);
    if (key.length < 5) return 0;
    return (_familyByStem[stem(key, 5)] ?? 1) - 1;
  }

  String semanticSetOf(String lemma) => stem(foldForComparison(lemma), 5);
}
