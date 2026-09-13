import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/originality.dart';
import 'package:content/src/validation/registry.dart';
import 'package:content/src/validation/runner.dart';

/// `dart run content:validate [--word <slug>] [--all] [--json]`
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('word', help: 'Validate a single word by slug.')
    ..addFlag('all', help: 'Validate the whole library (the default).')
    ..addFlag('json', help: 'Print the report as JSON.')
    ..addFlag(
      'probe-rae',
      help: 'Run the originality probe against rae.es (opt-in).',
    )
    ..addFlag(
      'network',
      help:
          'Allow --probe-rae to reach the network. Without it the probe uses '
          'the offline fetcher and finds nothing.',
    )
    ..addFlag(
      'catalog-simulation',
      defaultsTo: null,
      help:
          'Force the 90-day scheduling simulation on or off. Default: on for '
          '--all, off for --word.',
    )
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('list', help: 'List every validator and exit.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:validate [--word <slug>] [--all] [--json]')
      ..writeln(parser.usage);
    return;
  }

  if (args.flag('list')) {
    for (final validator in ValidatorRegistry.all(const OfflineFetcher())) {
      stdout.writeln(
        '${validator.severity.name.padRight(8)} '
        '${validator.code.padRight(26)} ${validator.description}',
      );
    }
    return;
  }

  final slug = args.option('word');
  final library = loadLibrary(root: args.option('root'), onlySlug: slug);
  if (slug != null && library.sources.isEmpty) {
    fail('no word file named $slug.yml in ${library.paths.wordsDir}');
  }

  final options = ValidationOptions(
    probeRae: args.flag('probe-rae'),
    enableCatalogSimulation: args.wasParsed('catalog-simulation')
        ? args.flag('catalog-simulation')
        : slug == null,
  );
  final runner = ValidationRunner(
    taxonomy: library.taxonomy,
    commonLemmas: library.commonLemmas,
    options: options,
    fetcher: args.flag('probe-rae') && args.flag('network')
        ? DuckDuckGoFetcher()
        : const OfflineFetcher(),
  );

  final report = await runner.run(library.sources);
  if (args.flag('json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    stdout.write(report.format());
  }
  exit(report.passed ? 0 : 1);
}
