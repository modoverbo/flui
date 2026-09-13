import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/gate/gate.dart';
import 'package:content/src/model/word_yaml.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:path/path.dart' as p;

/// `dart run content:gate-apply --results <file> [--results <file>]`
///
/// Scores the reviewers' answers, flips `status` to `gated` for the words both
/// passes answered perfectly, and writes precise failure reasons for the rest.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addMultiOption('results', help: 'Reviewer result JSON. Repeatable.')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('dry-run', help: 'Report without touching the word files.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:gate-apply --results <file>')
      ..writeln(parser.usage);
    return;
  }

  final files = args.multiOption('results');
  if (files.isEmpty) fail('pass at least one --results file');

  final results = <GateResults>[];
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) fail('no results file at $path');
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        fail('$path must contain a JSON object');
      }
      results.add(GateResults.fromJson(decoded));
    } on FormatException catch (error) {
      fail('$path is not a valid reviewer result: ${error.message}');
    }
  }

  final library = loadLibrary(root: args.option('root'));
  final outcome = applyGate(library.words, results);

  for (final slug in outcome.gated) {
    stdout.writeln('gated   $slug');
    if (args.flag('dry-run')) continue;
    final file = File(p.join(library.paths.wordsDir, '$slug.yml'));
    final map =
        loadYamlAsPlain(file.readAsStringSync())! as Map<String, Object?>;
    map['status'] = 'gated';
    map['provenance'] = <String, Object?>{
      ...?map['provenance'] as Map<String, Object?>?,
      'gate': 'dual-blind ${results.map((r) => r.reviewer).join(' + ')}',
      'checked_on': DateTime.now().toUtc().toIso8601String().split('T').first,
    };
    file.writeAsStringSync(writeWordYaml(map));
  }

  final failureDir = Directory(library.paths.gateDir)
    ..createSync(recursive: true);
  for (final entry in outcome.failures.entries) {
    stdout.writeln('FAILED  ${entry.key}');
    for (final reason in entry.value) {
      stdout.writeln('        $reason');
    }
    if (args.flag('dry-run')) continue;
    File(p.join(failureDir.path, '${entry.key}.failures.json'))
        .writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({
            'word': entry.key,
            'reasons': entry.value,
          })}\n',
        );
  }

  stdout.writeln(
    '${outcome.gated.length} gated, ${outcome.failures.length} failed',
  );
  exit(outcome.failures.isEmpty ? 0 : 1);
}
