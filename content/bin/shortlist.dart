import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/cli/shortlist.dart';
import 'package:content/src/corpus/candidate_pool.dart';
import 'package:path/path.dart' as p;

/// `dart run content:shortlist --theme <slug> [--limit <n>] [--json]`
///
/// Candidates for one theme that are already clear of the catalog rules: no
/// duplicate lemma, no family member, no paronym clash, no semantic-set clash
/// with anything the library holds.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('theme', help: 'Theme slug from content/themes.yml. Required.')
    ..addOption('limit', defaultsTo: '20', help: 'How many candidates.')
    ..addFlag('json', help: 'Print the report as JSON.')
    ..addFlag('all-themes', help: 'Print the count available per theme.')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:shortlist --theme <slug>')
      ..writeln(parser.usage);
    return;
  }

  final library = loadLibrary(root: args.option('root'));
  final candidatesFile = File(library.paths.candidatesFile);
  if (!candidatesFile.existsSync()) {
    fail(
      'no candidate pool at ${p.relative(candidatesFile.path)}; run '
      'dart run content:corpus first',
    );
  }
  final candidates = parseCsv(candidatesFile.readAsStringSync());
  final limit = int.tryParse(args.option('limit')!) ?? 20;

  if (args.flag('all-themes')) {
    final counts = <String, int>{};
    for (final theme in library.taxonomy.slugs) {
      counts[theme] = shortlistFor(
        theme: theme,
        candidates: candidates,
        library: library.words,
        limit: candidates.length,
      ).accepted.length;
    }
    if (args.flag('json')) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(counts));
      return;
    }
    final themes = counts.keys.toList()..sort();
    for (final theme in themes) {
      stdout.writeln('${theme.padRight(26)} ${counts[theme]}');
    }
    return;
  }

  final theme = args.option('theme') ?? '';
  if (theme.isEmpty) {
    fail('pass --theme <slug>, or --all-themes for the per-theme counts');
  }
  if (library.taxonomy.bySlug(theme) == null) {
    fail(
      'unknown theme "$theme"; content/themes.yml has '
      '${(library.taxonomy.slugs.toList()..sort()).join(', ')}',
    );
  }

  final result = shortlistFor(
    theme: theme,
    candidates: candidates,
    library: library.words,
    limit: limit,
  );
  if (args.flag('json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  } else {
    stdout.write(result.format());
  }
}
