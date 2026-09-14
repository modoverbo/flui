import 'dart:convert';

import 'package:content/src/text/spanish_text.dart';

/// `id \t word \t frequency`, the Leipzig word table.
Map<int, String> parseWordIds(String contents) {
  final words = <int, String>{};
  for (final line in const LineSplitter().convert(contents)) {
    if (line.isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length < 2) continue;
    final id = int.tryParse(parts[0].trim());
    if (id == null) continue;
    words[id] = parts[1];
  }
  return words;
}

/// Streams `co_s.txt` (`id1 \t id2 \t frequency \t significance`) as folded
/// word pairs.
///
/// Leipzig's sentence co-occurrence is the closest thing the download packages
/// give us to "these two words appear in the same statement". It is not a
/// dependency parse, so it cannot prove a shared *syntactic slot*; it proves a
/// shared context, which is what the pool actually scores on.
void streamCooccurrences({
  required Map<int, String> words,
  required String cooccurrences,
  required void Function(String a, String b, double significance) onPair,
}) {
  for (final line in const LineSplitter().convert(cooccurrences)) {
    if (line.isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length < 4) continue;
    final a = words[int.tryParse(parts[0].trim()) ?? -1];
    final b = words[int.tryParse(parts[1].trim()) ?? -1];
    if (a == null || b == null) continue;
    final significance = double.tryParse(parts[3].trim());
    if (significance == null || significance <= 0) continue;
    onPair(foldForComparison(a), foldForComparison(b), significance);
  }
}

/// Significance mass a word shares with each named group of seed words.
final class EvidenceIndex {
  const EvidenceIndex({
    required this.byGroup,
    required this.total,
    required this.groupTotals,
    required this.grandTotal,
  });

  final Map<String, Map<String, double>> byGroup;
  final Map<String, double> total;

  /// Mass the whole population puts on each group.
  final Map<String, double> groupTotals;

  /// Mass the whole population accumulated.
  final double grandTotal;

  double massOf(String word, String group) => byGroup[word]?[group] ?? 0;

  double totalMassOf(String word) => total[word] ?? 0;

  bool hasEvidence(String word) => (total[word] ?? 0) > 0;

  /// Share of a word's total co-occurrence mass that falls on [group].
  double shareOf(String word, String group) {
    final all = totalMassOf(word);
    if (all <= 0) return 0;
    return massOf(word, group) / all;
  }

  /// Share of the whole population's mass that falls on [group].
  ///
  /// The baseline exists because a raw share is mostly a frequency artefact:
  /// a very common word keeps company with everything, so it scores high on
  /// every group. Dividing by the baseline asks the useful question instead —
  /// does *this* word keep that company more than words in general do?
  double baselineShareOf(String group) {
    if (grandTotal <= 0) return 0;
    return (groupTotals[group] ?? 0) / grandTotal;
  }

  /// How many times more than average a word keeps a group's company.
  /// 1.0 is exactly average, 0 means no evidence either way.
  double liftOf(String word, String group) {
    final baseline = baselineShareOf(group);
    if (baseline <= 0) return 0;
    return shareOf(word, group) / baseline;
  }
}

/// Accumulates, for every interesting word, how much of its co-occurrence mass
/// falls on each seed group.
final class EvidenceBuilder {
  EvidenceBuilder({required this.interesting, required this.groups});

  final Set<String> interesting;
  final Map<String, Set<String>> groups;

  final Map<String, Map<String, double>> _byGroup = {};
  final Map<String, double> _total = {};

  void add(String a, String b, double significance) {
    _record(a, b, significance);
    _record(b, a, significance);
  }

  void _record(String word, String partner, double significance) {
    if (!interesting.contains(word)) return;
    _total[word] = (_total[word] ?? 0) + significance;
    for (final entry in groups.entries) {
      if (!entry.value.contains(partner)) continue;
      final buckets = _byGroup.putIfAbsent(word, () => <String, double>{});
      buckets[entry.key] = (buckets[entry.key] ?? 0) + significance;
    }
  }

  EvidenceIndex build() {
    final groupTotals = <String, double>{};
    for (final buckets in _byGroup.values) {
      for (final entry in buckets.entries) {
        groupTotals[entry.key] = (groupTotals[entry.key] ?? 0) + entry.value;
      }
    }
    return EvidenceIndex(
      byGroup: _byGroup,
      total: _total,
      groupTotals: groupTotals,
      grandTotal: _total.values.fold(0, (a, b) => a + b),
    );
  }
}

/// Collects the strongest co-occurrence partners of a seed set.
///
/// Used to discover, from the data, which nouns the comodín verbs actually
/// take as arguments.
final class CoOccurrenceCollector {
  CoOccurrenceCollector({required this.seeds, required this.keep});

  final Set<String> seeds;

  /// Filter for the partner side, e.g. "is a noun in the dictionary".
  final bool Function(String word) keep;

  final Map<String, double> _mass = {};

  void add(String a, String b, double significance) {
    _record(a, b, significance);
    _record(b, a, significance);
  }

  void _record(String seed, String partner, double significance) {
    if (!seeds.contains(seed)) return;
    if (!keep(partner)) return;
    _mass[partner] = (_mass[partner] ?? 0) + significance;
  }

  /// The [limit] strongest partners.
  Set<String> top(int limit) {
    final sorted = _mass.entries.toList()
      ..sort((a, b) {
        final byMass = b.value.compareTo(a.value);
        return byMass != 0 ? byMass : a.key.compareTo(b.key);
      });
    return {for (final entry in sorted.take(limit)) entry.key};
  }

  int get length => _mass.length;
}
