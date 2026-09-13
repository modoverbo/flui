import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/gate/gate.dart';
import 'package:path/path.dart' as p;

/// `dart run content:gate-prepare [--word <slug>] [--status validated]`
///
/// Writes two blind task packs per word, one per reviewer pass, with the
/// options shuffled differently and the answer withheld.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('word', help: 'Prepare a single word by slug.')
    ..addOption(
      'status',
      defaultsTo: 'validated',
      help: 'Only prepare words in this status. Use "any" for all of them.',
    )
    ..addOption('out', help: 'Output directory. Default: content/gate')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:gate-prepare [--word <slug>]')
      ..writeln(parser.usage);
    return;
  }

  final library = loadLibrary(
    root: args.option('root'),
    onlySlug: args.option('word'),
  );
  final wanted = args.option('status');
  final words = [
    for (final word in library.words)
      if (wanted == 'any' || word.status.name == wanted) word,
  ];
  if (words.isEmpty) {
    fail('no word with status "$wanted"; nothing to prepare');
  }

  final outDir = Directory(args.option('out') ?? library.paths.gateDir)
    ..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final word in words) {
    for (final pass in GatePass.values) {
      final file =
          File(p.join(outDir.path, '${word.slug}.pass-${pass.name}.json'))
            ..writeAsStringSync(
              '${encoder.convert(buildGatePack(word, pass).toJson())}\n',
            );
      stdout.writeln('wrote ${p.relative(file.path)}');
    }
  }
  stdout.writeln(
    'prepared ${words.length} words x ${GatePass.values.length} passes; '
    'hand each pass to a different reviewing agent, then run '
    'dart run content:gate-apply --results <file>',
  );
}
