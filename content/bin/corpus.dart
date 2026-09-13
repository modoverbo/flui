import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/corpus/candidate_pool.dart';
import 'package:content/src/corpus/leipzig.dart';
import 'package:path/path.dart' as p;

/// `dart run content:corpus`
///
/// Downloads the Leipzig Corpora Collection Spanish packages (CC BY 4.0; the
/// attribution lives in content/data/LICENSES.md), then computes the candidate
/// pool and the common-word list. The CC BY-NC web API is never used.
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
  final source = LeipzigDownloader(
    cacheDir: cacheDir,
    log: stdout.writeln,
  );

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

  final pool = buildCandidatePool(
    loaded,
    limit: int.parse(args.option('limit')!),
  );
  candidatesFile.writeAsStringSync(toCsv(pool));
  stdout.writeln(
    'wrote ${pool.length} candidates to ${p.relative(candidatesFile.path)}',
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
