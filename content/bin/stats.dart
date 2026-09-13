import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/cli/stats.dart';

/// `dart run content:stats`
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addFlag('json', help: 'Print the report as JSON.')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:stats')
      ..writeln(parser.usage);
    return;
  }

  final library = loadLibrary(root: args.option('root'));
  final stats = catalogStats(library.words, library.taxonomy);
  if (args.flag('json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(stats.toJson()));
  } else {
    stdout.write(stats.format());
  }
}
