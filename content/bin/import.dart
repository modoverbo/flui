import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/model/word_yaml.dart';
import 'package:content/src/sql/seed_emitter.dart';
import 'package:content/src/sql/seed_importer.dart';
import 'package:path/path.dart' as p;

/// `dart run content:import --from supabase/seed.sql`
///
/// One-shot converter. After it runs, `content/words/*.yml` is the source of
/// truth and `content:emit` regenerates the seed from it.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('from', help: 'Path to the seed file to import.')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('force', help: 'Overwrite word files that already exist.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:import --from supabase/seed.sql')
      ..writeln(parser.usage);
    return;
  }

  final library = loadLibrary(root: args.option('root'));
  final seedPath = args.option('from') ?? library.paths.defaultSeedFile;
  final seedFile = File(seedPath);
  if (!seedFile.existsSync()) fail('no seed file at $seedPath');

  final sql = seedFile.readAsStringSync();
  final parts = splitSeed(sql);
  final preambleFile = File(library.paths.seedPreambleFile)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(parts.preamble);
  stdout.writeln('wrote ${p.relative(preambleFile.path)}');

  Directory(library.paths.wordsDir).createSync(recursive: true);
  var written = 0;
  var skipped = 0;
  for (final word in importSeedWords(sql)) {
    final slug = word['slug']! as String;
    final target = File(p.join(library.paths.wordsDir, '$slug.yml'));
    if (target.existsSync() && !args.flag('force')) {
      stdout.writeln('skipped $slug.yml (already exists; pass --force)');
      skipped++;
      continue;
    }
    target.writeAsStringSync(
      writeWordYaml(
        word,
        header:
            'Imported from ${p.relative(seedPath)} by dart run content:import.\n'
            'This file is now the source of truth; regenerate the seed with\n'
            'dart run content:emit. Authored before the validator suite existed,\n'
            'so dart run content:validate is expected to report gaps.',
      ),
    );
    written++;
  }
  stdout.writeln('imported $written words, skipped $skipped');
}
