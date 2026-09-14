import 'package:content/src/corpus/cooccurrence.dart';
import 'package:content/src/corpus/corpus_index.dart';
import 'package:content/src/corpus/domain_seeds.dart';
import 'package:content/src/corpus/leipzig.dart';
import 'package:content/src/corpus/lexicon.dart';

/// How many comodín arguments to keep. Enough to cover what "hacer", "poner"
/// and friends actually take, small enough that the overlap still means
/// something.
const comodinArgumentLimit = 3000;

/// How many immediate neighbours define the comodín slot profile.
const comodinNeighbourLimit = 2000;

/// Group name for the comodín slot signal.
const slotGroup = 'slot';

/// The two kinds of co-occurrence evidence the pool scores on.
///
/// They answer different questions and come from different Leipzig tables:
/// - [slot] comes from `co_n.txt`, immediate neighbours. Two words that take
///   the same neighbours stand in the same syntactic slot, which is as close
///   as these packages get to "can this word replace that one".
/// - [topic] comes from `co_s.txt`, same-sentence company. That is a topical
///   signal, and it is what the domain and theme gates read.
final class CorpusEvidence {
  const CorpusEvidence({
    required this.slot,
    required this.topic,
    required this.comodinArguments,
    required this.comodinNeighbours,
    required this.packagesWithCooccurrence,
  });

  final EvidenceIndex slot;
  final EvidenceIndex topic;
  final Set<String> comodinArguments;
  final Set<String> comodinNeighbours;
  final int packagesWithCooccurrence;
}

/// Builds the evidence index in two passes over the sentence co-occurrence
/// tables.
///
/// Pass 1 discovers, from the data, which nouns the comodín verbs keep company
/// with. Pass 2 measures how much of each candidate's own company falls on
/// those nouns, on abstract vocabulary, on physical vocabulary and on each
/// theme's vocabulary.
Future<CorpusEvidence?> buildCorpusEvidence({
  required List<LeipzigPackage> packages,
  required CorpusSource source,
  required CorpusIndex corpus,
  required SpanishLexicon lexicon,
  required Set<String> interesting,
  void Function(String message)? log,
}) async {
  final sentences = <LeipzigPackage, (Map<int, String>, String)>{};
  final adjacent = <LeipzigPackage, (Map<int, String>, String)>{};
  for (final package in packages) {
    final ids = await source.wordIds(package);
    if (ids == null) continue;
    final co = await source.cooccurrences(package);
    if (co != null) sentences[package] = (ids, co);
    final neighbours = await source.neighbours(package);
    if (neighbours != null) adjacent[package] = (ids, neighbours);
  }
  if (sentences.isEmpty && adjacent.isEmpty) return null;

  void stream(
    Map<LeipzigPackage, (Map<int, String>, String)> tables,
    void Function(String a, String b, double sig) onPair,
  ) {
    for (final entry in tables.values) {
      final (ids, table) = entry;
      streamCooccurrences(
        words: ids,
        cooccurrences: table,
        onPair: (a, b, sig) =>
            onPair(corpus.lemmaKeyOf(a), corpus.lemmaKeyOf(b), sig),
      );
    }
  }

  log?.call('pass 1: comodín arguments (co_s) and slot neighbours (co_n)');
  final arguments = CoOccurrenceCollector(
    seeds: comodinWords,
    keep: (word) =>
        !comodinWords.contains(word) &&
        (lexicon.isEmpty || lexicon.isNoun(corpus.lemmaKeyOf(word))),
  );
  stream(sentences, arguments.add);
  final comodinArguments = arguments.top(comodinArgumentLimit);

  final neighbours = CoOccurrenceCollector(
    seeds: comodinWords,
    keep: (word) => !comodinWords.contains(word),
  );
  stream(adjacent, neighbours.add);
  final comodinNeighbours = neighbours.top(comodinNeighbourLimit);
  log?.call(
    'comodín arguments: ${comodinArguments.length}, '
    'slot neighbours: ${comodinNeighbours.length}',
  );

  log?.call('pass 2: scoring candidate company');
  final slotBuilder = EvidenceBuilder(
    interesting: interesting,
    groups: {slotGroup: comodinNeighbours},
  );
  stream(adjacent, slotBuilder.add);

  final topicBuilder = EvidenceBuilder(
    interesting: interesting,
    groups: {
      comodinGroup: comodinArguments,
      abstractGroup: abstractMarkers,
      physicalGroup: physicalMarkers,
      for (final entry in themeMarkers.entries)
        themeGroup(entry.key): entry.value,
    },
  );
  stream(sentences, topicBuilder.add);

  return CorpusEvidence(
    slot: slotBuilder.build(),
    topic: topicBuilder.build(),
    comodinArguments: comodinArguments,
    comodinNeighbours: comodinNeighbours,
    packagesWithCooccurrence: sentences.length,
  );
}
