import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/cli/prune.dart';
import 'package:content/src/model/word_yaml.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:path/path.dart' as p;

/// `dart run content:prune --word <slug>`
///
/// Removes the exercises `content/gate/<slug>.failures.json` names and
/// renumbers what is left, so a word reaches the catalog with fewer items
/// rather than with rewritten ones the gate would only break again.
///
/// It refuses when the result would fall under the exercise floor or lose the
/// paronym/register coverage, prints what would be missing and exits non-zero:
/// those words need authoring, not pruning.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('word', help: 'The slug to prune. Required.')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('dry-run', help: 'Report without touching the word file.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:prune --word <slug>')
      ..writeln(parser.usage);
    return;
  }

  final slug = args.option('word');
  if (slug == null) fail('pass --word <slug>');

  final paths = loadLibrary(root: args.option('root'), onlySlug: slug).paths;
  final wordFile = File(p.join(paths.wordsDir, '$slug.yml'));
  if (!wordFile.existsSync()) {
    fail('no word file at ${p.relative(wordFile.path)}');
  }
  final failuresFile = File(p.join(paths.gateDir, '$slug.failures.json'));
  if (!failuresFile.existsSync()) {
    fail(
      'no ${p.relative(failuresFile.path)}; $slug has nothing the gate asked '
      'to remove',
    );
  }

  final List<String> reasons;
  try {
    reasons = parseFailureReasons(jsonDecode(failuresFile.readAsStringSync()));
  } on FormatException catch (error) {
    fail(
      '${p.relative(failuresFile.path)} is not a gate failures file: '
      '${error.message}',
    );
  }

  final word = loadYamlAsPlain(wordFile.readAsStringSync());
  if (word is! Map<String, Object?>) {
    fail('${p.relative(wordFile.path)} is not a YAML mapping');
  }

  final plan = planPrune(
    slug: slug,
    word: word,
    failed: failedExercisePositions(reasons),
  );

  if (plan.refused) {
    stderr.writeln('REFUSED $slug');
    for (final refusal in plan.refusals) {
      stderr.writeln('        $refusal');
    }
    exit(1);
  }

  if (plan.dropped.isEmpty) {
    stdout.writeln(
      'nothing to prune in $slug: the failures file names no exercise',
    );
    return;
  }

  stdout.writeln(
    'pruned  $slug: dropped exercise ${plan.dropped.join(', ')}, '
    'kept ${plan.kept}',
  );
  if (args.flag('dry-run')) return;
  wordFile.writeAsStringSync(writeWordYaml(plan.word!));

  // The reasons name positions that no longer exist: the survivors have been
  // renumbered. Running this twice would silently delete a second, innocent
  // set of exercises, so the work order is consumed with the work. What was
  // removed survives in `provenance.gate`, and `content:gate-prepare` plus a
  // fresh gate run is what writes a new one.
  failuresFile.deleteSync();
  stdout.writeln(
    '        consumed ${p.relative(failuresFile.path)}; re-run the gate to '
    'judge what is left',
  );
}
