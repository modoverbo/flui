// Proves that a candidate seed file produces the committed fake-backend
// fixture byte for byte, without writing anything into lib/.
//
// Usage (from app/):
//   dart run tool/seed_fixture_check.dart --seed ../supabase/seed.sql
//   dart run tool/seed_fixture_check.dart --seed /tmp/seed.emitted.sql
//
// It parses the seed with tool/seed/seed_parser.dart, renders the fixture with
// the same renderer tool/seed_to_fixture.dart uses, formats it the same way,
// and diffs it against lib/features/vocabulary/data/fake/seed_content.dart.
// Exit code 0 means the bytes match.
import 'dart:io';

import 'seed/seed_parser.dart';
import 'seed_to_fixture.dart' show renderSeedFixture;

const _fixturePath = 'lib/features/vocabulary/data/fake/seed_content.dart';

Future<void> main(List<String> arguments) async {
  var seedPath = '../supabase/seed.sql';
  for (var i = 0; i < arguments.length - 1; i++) {
    if (arguments[i] == '--seed') seedPath = arguments[i + 1];
  }

  final seed = File(seedPath);
  if (!seed.existsSync()) {
    stderr.writeln('no seed file at $seedPath');
    exit(2);
  }

  final sql = seed.readAsStringSync();
  final words = parseSeedWords(sql);
  final scratch = await Directory.systemTemp.createTemp('flui-fixture-');
  final candidate = File('${scratch.path}/seed_content.dart')
    ..writeAsStringSync(
      renderSeedFixture(words, themeSlugs: parseSeedWordThemeSlugs(sql)),
    );
  final format = await Process.run('dart', ['format', candidate.path]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stderr);
    exit(2);
  }

  final expected = File(_fixturePath).readAsBytesSync();
  final actual = candidate.readAsBytesSync();
  scratch.deleteSync(recursive: true);

  stdout
    ..writeln('seed:     $seedPath (${words.length} words)')
    ..writeln('fixture:  $_fixturePath');
  final same =
      actual.length == expected.length &&
      List.generate(
        actual.length,
        (i) => actual[i] == expected[i],
      ).every((m) => m);
  if (same) {
    stdout.writeln('result:   byte-identical (${actual.length} bytes)');
    return;
  }
  stdout.writeln(
    'result:   DIFFERENT (${actual.length} vs ${expected.length} bytes)',
  );
  exit(1);
}
