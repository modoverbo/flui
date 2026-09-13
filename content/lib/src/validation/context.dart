import 'package:content/src/model/theme.dart';
import 'package:content/src/model/word.dart';

/// Tunable thresholds. They live in one place so a report can print the exact
/// numbers a run used, and so no validator hides a magic constant.
final class ValidationOptions {
  const ValidationOptions({
    this.sentenceShingleSize = 3,
    this.sentenceJaccardThreshold = 0.7,
    this.openingTrigramLimitPerWord = 2,
    this.frameReuseLimit = 12,
    this.namePercentLimit = 15,
    this.nameCheckMinSentences = 20,
    this.schedulingDays = 90,
    this.minEligiblePerDay = 3,
    this.enableCatalogSimulation = true,
    this.explanationMaxWords = 20,
    this.hintMaxWords = 25,
    this.leakStemLength = 5,
    this.maxPedantryForApproved = 2,
    this.probeRae = false,
  });

  final int sentenceShingleSize;
  final double sentenceJaccardThreshold;
  final int openingTrigramLimitPerWord;

  /// Library-wide cap on how often one syntactic frame may be reused (K).
  final int frameReuseLimit;

  /// Share of library sentences a single personal name may reach (N).
  final int namePercentLimit;

  /// Below this many sentences a percentage says nothing, so the check sleeps.
  final int nameCheckMinSentences;

  final int schedulingDays;
  final int minEligiblePerDay;

  /// The 90-day simulation is a catalog-scale gate. `--word <slug>` turns it
  /// off so an authoring agent can self-check one file.
  final bool enableCatalogSimulation;
  final int explanationMaxWords;
  final int hintMaxWords;
  final int leakStemLength;
  final int maxPedantryForApproved;
  final bool probeRae;

  ValidationOptions copyWith({
    bool? probeRae,
    bool? enableCatalogSimulation,
  }) => ValidationOptions(
    sentenceShingleSize: sentenceShingleSize,
    sentenceJaccardThreshold: sentenceJaccardThreshold,
    openingTrigramLimitPerWord: openingTrigramLimitPerWord,
    frameReuseLimit: frameReuseLimit,
    namePercentLimit: namePercentLimit,
    nameCheckMinSentences: nameCheckMinSentences,
    schedulingDays: schedulingDays,
    minEligiblePerDay: minEligiblePerDay,
    enableCatalogSimulation:
        enableCatalogSimulation ?? this.enableCatalogSimulation,
    explanationMaxWords: explanationMaxWords,
    hintMaxWords: hintMaxWords,
    leakStemLength: leakStemLength,
    maxPedantryForApproved: maxPedantryForApproved,
    probeRae: probeRae ?? this.probeRae,
  );
}

/// Everything a validator may look at beyond the word in front of it.
final class LibraryContext {
  const LibraryContext({
    required this.words,
    required this.taxonomy,
    this.commonLemmas,
    this.options = const ValidationOptions(),
  });

  final List<Word> words;
  final ThemeTaxonomy taxonomy;

  /// Top-N Spanish lemma list, or null when `content/data` has none yet.
  final Set<String>? commonLemmas;

  final ValidationOptions options;
}
