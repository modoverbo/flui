import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/corpus/candidate_pool.dart';
import 'package:content/src/corpus/leipzig.dart';
import 'package:content/src/corpus/lexicon.dart';
import 'package:content/src/corpus/pipeline.dart';
import 'package:content/src/text/spanish_morphology.dart';
import 'package:path/path.dart' as p;

/// `dart run content:corpus`
///
/// Downloads the Leipzig Corpora Collection Spanish packages (CC BY 4.0; the
/// attribution lives in content/data/LICENSES.md) and the Wikidata Spanish
/// lexeme list (CC0), then computes the candidate pool, the common-word list
/// and the dictionary. The CC BY-NC Leipzig web API is never used.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'cache',
      help: 'Download cache directory. Default: .corpus-cache',
    )
    ..addOption('limit', defaultsTo: '1500', help: 'Rows in candidates.csv.')
    ..addOption(
      'common-limit',
      defaultsTo: '5000',
      help: 'Lemmas in common_lemmas_es.txt.',
    )
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag(
      'refresh-lexicon',
      help: 'Re-query Wikidata even when data/lexemes_es.tsv exists.',
    )
    ..addFlag(
      'no-cooccurrence',
      help:
          'Skip the co-occurrence passes. The pool then carries '
          'domain-unverified and has no evidence-based themes.',
    )
    ..addFlag(
      'offline',
      help:
          'Do not download. Emit the documented editorial fallback list with '
          'metrics_pending: true instead of inventing numbers.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:corpus')
      ..writeln(parser.usage);
    return;
  }

  final library = loadLibrary(root: args.option('root'));
  final dataDir = Directory(library.paths.dataDir)..createSync(recursive: true);
  final candidatesFile = File(library.paths.candidatesFile);

  if (args.flag('offline')) {
    final fallbackFile = File(p.join(dataDir.path, 'editorial_fallback.txt'));
    if (!fallbackFile.existsSync()) {
      fail('no editorial fallback list at ${p.relative(fallbackFile.path)}');
    }
    final lemmas = [
      for (final line in fallbackFile.readAsLinesSync())
        if (line.trim().isNotEmpty && !line.startsWith('#')) line.trim(),
    ];
    candidatesFile.writeAsStringSync(toCsv(fallbackPool(lemmas)));
    stdout.writeln(
      'offline: wrote ${lemmas.length} editorial candidates with '
      'metrics_pending=true to ${p.relative(candidatesFile.path)}',
    );
    return;
  }

  final cacheDir =
      args.option('cache') ?? p.join(library.paths.root, '.corpus-cache');
  Directory(cacheDir).createSync(recursive: true);
  final source = LeipzigDownloader(cacheDir: cacheDir, log: stdout.writeln);

  final loaded = <PackageCounts>[];
  final failures = <String>[];
  for (final package in defaultPackages) {
    try {
      loaded.add(PackageCounts(package, await source.wordFrequencies(package)));
    } on Object catch (error) {
      failures.add('${package.name}: $error');
      stderr.writeln('warning: could not load ${package.name}: $error');
    }
  }
  if (loaded.isEmpty) {
    fail(
      'every download failed; rerun with --offline to emit the editorial '
      'fallback list instead. First error: ${failures.first}',
    );
  }

  final countries = loaded
      .where((c) => c.package.role == CorpusRole.country)
      .length;
  stdout.writeln(
    'loaded ${loaded.length} packages ($countries country subcorpora), '
    '${loaded.fold<int>(0, (a, b) => a + b.total)} tokens',
  );

  // The dictionary gate. CC0, so it ships with the repository.
  final lexiconFile = File(library.paths.lexiconFile);
  var lexicon = const SpanishLexicon({});
  if (!args.flag('refresh-lexicon') && lexiconFile.existsSync()) {
    lexicon = await CachedLexiconSource(lexiconFile.path).fetch();
    stdout.writeln('dictionary: ${lexicon.length} lemmas from the cached list');
  } else {
    try {
      lexicon = await WikidataLexiconSource(log: stdout.writeln).fetch();
      lexiconFile.writeAsStringSync(lexicon.toTsv());
      stdout.writeln(
        'dictionary: ${lexicon.length} Spanish lexemes written to '
        '${p.relative(lexiconFile.path)}',
      );
    } on Object catch (error) {
      stderr.writeln(
        'warning: could not fetch the Wikidata lexeme list ($error); '
        'the pool will be dictionary-unverified',
      );
    }
  }

  final corpus = CorpusIndex.build(loaded);

  CorpusEvidence? evidence;
  if (!args.flag('no-cooccurrence')) {
    final interesting = <String>{
      for (final lemma in corpus.lemmas)
        if (lemma.length >= 4 &&
            !spanishFunctionWords.contains(lemma) &&
            (lexicon.isEmpty || lexicon.contains(lemma)))
          lemma,
    };
    evidence = await buildCorpusEvidence(
      packages: defaultPackages,
      source: source,
      corpus: corpus,
      lexicon: lexicon,
      interesting: interesting,
      log: stdout.writeln,
    );
    if (evidence == null) {
      stderr.writeln(
        'warning: no co-occurrence tables were available; the pool will be '
        'domain-unverified and carry no themes',
      );
    }
  }

  final pool = buildCandidatePool(
    loaded,
    lexicon: lexicon,
    evidence: evidence?.topic,
    slotEvidence: evidence?.slot,
    prebuiltIndex: corpus,
    limit: int.parse(args.option('limit')!),
  );
  candidatesFile.writeAsStringSync(toCsv(pool));
  final themed = pool.where((r) => r.suggestedThemes.isNotEmpty).length;
  stdout.writeln(
    'wrote ${pool.length} candidates to ${p.relative(candidatesFile.path)} '
    '($themed with an evidence-backed theme)',
  );

  final common = topLemmas(
    loaded,
    limit: int.parse(args.option('common-limit')!),
  );
  File(library.paths.commonLemmasFile).writeAsStringSync(
    '${[
      '# Top ${common.length} Spanish lemmas by frequency, accent-folded',
      '# (rapido, not rápido): the validator compares folded forms.',
      '# Source: Leipzig Corpora Collection Spanish packages (CC BY 4.0).',
      '# Built by: dart run content:corpus. See LICENSES.md.',
      ...common,
    ].join('\n')}\n',
  );
  stdout.writeln(
    'wrote ${common.length} lemmas to '
    '${p.relative(library.paths.commonLemmasFile)}',
  );
  if (failures.isNotEmpty) {
    stdout.writeln('${failures.length} packages were skipped:');
    for (final failure in failures) {
      stdout.writeln('  $failure');
    }
  }
}
