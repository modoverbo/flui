import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/corpus/candidate_pool.dart';
import 'package:content/src/corpus/domain_seeds.dart';
import 'package:content/src/corpus/leipzig.dart';
import 'package:content/src/corpus/lexicon.dart';
import 'package:content/src/corpus/metrics.dart';
import 'package:content/src/corpus/pipeline.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:path/path.dart' as p;

/// `dart run content:metrics --lemma <x> [--json] [--evidence]`
///
/// Works for any lemma the corpus contains, not only the rows that made
/// `candidates.csv`, so an authoring agent can justify a word it proposes
/// itself. Says plainly when the corpus has never seen the word.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('lemma', help: 'The lemma to measure. Required.')
    ..addFlag('json', help: 'Print the report as JSON.')
    ..addFlag(
      'evidence',
      help:
          'Also run the co-occurrence passes for the comodín leverage, the '
          'domain score and the themes. Slower: it reads every co-occurrence '
          'table in the cache.',
    )
    ..addOption('cache', help: 'Corpus cache directory. Default: .corpus-cache')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:metrics --lemma <lemma>')
      ..writeln(parser.usage);
    return;
  }

  final lemmaArg = args.option('lemma')?.trim() ?? '';
  if (lemmaArg.isEmpty) fail('pass --lemma <lemma>');
  final lemma = foldForComparison(lemmaArg);

  final library = loadLibrary(root: args.option('root'));
  final cacheDir = args.option('cache') ?? library.paths.corpusCacheDir;
  if (!Directory(cacheDir).existsSync()) {
    fail(
      'no corpus cache at ${p.relative(cacheDir)}; run dart run content:corpus '
      'first',
    );
  }

  final source = LeipzigDownloader(cacheDir: cacheDir);
  final loaded = <PackageCounts>[];
  for (final package in defaultPackages) {
    final words = File(p.join(cacheDir, '${package.name}-words.txt'));
    if (!words.existsSync()) continue;
    loaded.add(PackageCounts(package, await source.wordFrequencies(package)));
  }
  if (loaded.isEmpty) {
    fail('the cache at ${p.relative(cacheDir)} holds no extracted packages');
  }

  final corpus = CorpusIndex.build(loaded);
  final lexicon = await CachedLexiconSource(library.paths.lexiconFile).fetch();
  final key = corpus.lemmaKeyOf(lemma);
  final found = corpus.contains(key);

  final report = <String, Object?>{
    'lemma': lemmaArg,
    'corpus_lemma': found ? corpus.display(key) : null,
    'found': found,
    'packages': loaded.length,
    'country_subcorpora': corpus.countryPackages.length,
    'in_dictionary': lexicon.isEmpty ? null : lexicon.contains(key),
    'dictionary_pos': lexicon.partOfSpeechFor(key),
  };

  if (!found) {
    report['message'] =
        'the corpus never saw "$lemmaArg" (folded: $lemma). It may be '
        'rarer than the 100K-sentence packages reach, or spelled differently. '
        'No metric can be reported for it, and none is invented.';
    _emit(args.flag('json'), report, exitCode: 1);
    return;
  }

  final frequency = corpus.frequencyOf(key);
  final observed = corpus.countryCountsOf(key);
  final missing = observed.where((v) => v == 0).length;
  report.addAll({
    'frequency': frequency,
    'zipf': corpus.zipfOf(key),
    'dispersion_dp': corpus.dispersionOf(key),
    'pedantry_proxy': corpus.pedantryOf(key),
    'formal_per_million': corpus.formalPerMillionOf(key),
    'informal_per_million': corpus.informalPerMillionOf(key),
    'family_size': corpus.familySizeOf(key),
    'semantic_set': corpus.semanticSetOf(key),
    'part_of_speech':
        lexicon.partOfSpeechFor(key) ?? guessPartOfSpeech(corpus.display(key)),
    'by_country': {
      for (var i = 0; i < observed.length; i++)
        corpus.countryCodes[i]: observed[i],
    },
    'zipf_band': '$idealZipfLow..$idealZipfHigh',
    'in_zipf_band':
        corpus.zipfOf(key) >= idealZipfLow &&
        corpus.zipfOf(key) <= idealZipfHigh,
  });

  final flags = <String>[
    if (corpus.dispersionOf(key) > 0.45 || missing > observed.length * 0.6)
      'regional-only',
    if (lexicon.isNotEmpty && !lexicon.contains(key)) 'not-in-dictionary',
    if (lexicon.isEmpty) 'dictionary-unverified',
    if (looksInflected(corpus.display(key))) 'looks-inflected',
    if (looksForeign(corpus.display(key))) 'looks-foreign',
    'semantic-set:${corpus.semanticSetOf(key)}',
  ];

  if (args.flag('evidence')) {
    final evidence = await buildCorpusEvidence(
      packages: defaultPackages,
      source: source,
      corpus: corpus,
      lexicon: lexicon,
      interesting: {key},
      log: args.flag('json') ? null : stdout.writeln,
    );
    if (evidence == null) {
      report['evidence'] = null;
      flags.add('domain-unverified');
    } else {
      final abstractMass = evidence.topic.massOf(key, abstractGroup);
      final physicalMass = evidence.topic.massOf(key, physicalGroup);
      report['evidence'] = {
        // Leverage is a rank inside the pool, so a single lemma only gets the
        // raw lift it was ranked on.
        'slot_lift': evidence.slot.liftOf(key, slotGroup),
        'comodin_argument_lift': evidence.topic.liftOf(key, comodinGroup),
        'abstract_lift': evidence.topic.liftOf(key, abstractGroup),
        'domain_score': abstractMass + physicalMass <= 0
            ? null
            : abstractMass / (abstractMass + physicalMass),
        'abstract_mass': abstractMass,
        'physical_mass': physicalMass,
        'themes': {
          for (final theme in themeMarkers.keys)
            if (evidence.topic.liftOf(key, themeGroup(theme)) >=
                const PoolPolicy().themeMinimumLift)
              theme: evidence.topic.liftOf(key, themeGroup(theme)),
        },
      };
    }
  }

  report['flags'] = flags;
  _emit(args.flag('json'), report);
}

void _emit(bool asJson, Map<String, Object?> report, {int exitCode = 0}) {
  if (asJson) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } else {
    final keys = report.keys.toList();
    for (final key in keys) {
      final value = report[key];
      if (value == null) continue;
      if (value is Map || value is List) {
        stdout.writeln('${key.padRight(22)} ${jsonEncode(value)}');
      } else if (value is double) {
        stdout.writeln('${key.padRight(22)} ${value.toStringAsFixed(4)}');
      } else {
        stdout.writeln('${key.padRight(22)} $value');
      }
    }
  }
  if (exitCode != 0) exit(exitCode);
}
