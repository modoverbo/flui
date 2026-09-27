import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/sql/seed_emitter.dart';
import 'package:path/path.dart' as p;

/// `dart run content:emit --out supabase/seed.sql`
///
/// Deterministic: the same word files always produce the same bytes.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'out',
      help: 'Where to write the seed. Default: supabase/seed.sql',
    )
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('stdout', help: 'Write to stdout instead of a file.')
    ..addFlag('check', help: 'Exit 1 when the target file would change.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:emit --out supabase/seed.sql')
      ..writeln(parser.usage);
    return;
  }

  final library = loadLibrary(root: args.option('root'));
  final preambleFile = File(library.paths.seedPreambleFile);
  if (!preambleFile.existsSync()) {
    fail(
      'missing ${p.relative(preambleFile.path)}; run dart run content:import '
      'once to capture the seed preamble',
    );
  }

  final words = approvedWordsInOrder(library.words);
  if (words.isEmpty) fail('no word has status: approved, nothing to emit');
  final challenges = approvedChallengesInOrder(library.challenges);

  final sql = emitSeed(
    preamble: preambleFile.readAsStringSync(),
    words: words,
    challenges: challenges,
  );

  if (args.flag('stdout')) {
    stdout.write(sql);
    return;
  }

  final target = File(args.option('out') ?? library.paths.defaultSeedFile);
  if (args.flag('check')) {
    final current = target.existsSync() ? target.readAsStringSync() : '';
    if (current == sql) {
      stdout.writeln('${p.relative(target.path)} is up to date');
      return;
    }
    stderr.writeln('${p.relative(target.path)} is stale; run content:emit');
    exit(1);
  }

  target
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(sql);
  stdout.writeln(
    'wrote ${words.length} approved words and ${challenges.length} approved '
    'challenges to ${p.relative(target.path)}',
  );
}
