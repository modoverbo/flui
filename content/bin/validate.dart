import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/model/challenge.dart';
import 'package:content/src/validation/challenge_validators.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/originality.dart';
import 'package:content/src/validation/registry.dart';
import 'package:content/src/validation/runner.dart';

/// Runs [ChallengeValidatorRegistry] over every loaded challenge source.
///
/// Deliberately lighter than [ValidationRunner]: there is no library-level
/// pass (unique slugs / slot coverage / mode coverage) yet — those need
/// authored content to check meaningfully (content/challenges/*.yml lands
/// in U6a/U6b) and are deferred there.
Map<String, List<Issue>> _validateChallenges(LoadedLibrary library) {
  final issuesBySlug = <String, List<Issue>>{};
  for (final source in library.challengeSources) {
    final issues = <Issue>[];
    if (source.parseError != null) {
      issues.add(
        Issue(
          code: 'yaml',
          severity: Severity.blocking,
          slug: source.slug,
          location: source.path,
          message: 'could not parse the file: ${source.parseError}',
        ),
      );
      issuesBySlug[source.slug] = issues;
      continue;
    }
    for (final validator in ChallengeValidatorRegistry.rawValidators) {
      issues.addAll(validator.validateRaw(source.slug, source.raw));
    }
    try {
      final challenge = Challenge.fromMap(source.raw);
      for (final validator in ChallengeValidatorRegistry.challengeValidators) {
        issues.addAll(validator.validateChallenge(challenge));
      }
    } on FormatException catch (error) {
      issues.add(
        Issue(
          code: 'model',
          severity: Severity.blocking,
          slug: source.slug,
          location: 'file',
          message: 'could not build the challenge model: ${error.message}',
        ),
      );
    }
    issuesBySlug[source.slug] = issues;
  }
  return issuesBySlug;
}

/// `dart run content:validate [--word <slug>] [--challenge <slug>] [--all] [--json]`
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('word', help: 'Validate a single word by slug.')
    ..addOption('challenge', help: 'Validate a single challenge by slug.')
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
    for (final validator in ChallengeValidatorRegistry.all()) {
      stdout.writeln(
        '${validator.severity.name.padRight(8)} '
        '${validator.code.padRight(26)} ${validator.description}',
      );
    }
    return;
  }

  final slug = args.option('word');
  final challengeSlug = args.option('challenge');
  final library = loadLibrary(
    root: args.option('root'),
    onlySlug: slug,
    onlyChallengeSlug: challengeSlug,
  );
  if (slug != null && library.sources.isEmpty) {
    fail('no word file named $slug.yml in ${library.paths.wordsDir}');
  }
  if (challengeSlug != null && library.challengeSources.isEmpty) {
    fail(
      'no challenge file named $challengeSlug.yml in '
      '${library.paths.challengesDir}',
    );
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
  final challengeIssues = _validateChallenges(library);
  final challengeAllIssues = [
    for (final issues in challengeIssues.values) ...issues,
  ];
  final challengeBlocking = challengeAllIssues
      .where((i) => i.isBlocking)
      .length;
  final challengesPassed = challengeBlocking == 0;

  if (args.flag('json')) {
    final json = report.toJson()
      ..['challenges'] = library.challengeSources.length
      ..['challengesBlocking'] = challengeBlocking
      ..['challengesPassed'] = challengesPassed
      ..['byChallenge'] = {
        for (final entry in challengeIssues.entries)
          entry.key: [for (final issue in entry.value) issue.toJson()],
      };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(json));
  } else {
    stdout.write(report.format());
    if (challengeIssues.isNotEmpty) {
      stdout.writeln();
      final slugs = challengeIssues.keys.toList()..sort();
      for (final challengeSlugKey in slugs) {
        final issues = challengeIssues[challengeSlugKey]!;
        final blocking = issues.where((i) => i.isBlocking).length;
        final warns = issues.length - blocking;
        final mark = blocking == 0 ? (warns == 0 ? 'ok  ' : 'warn') : 'FAIL';
        stdout.writeln(
          '$mark  $challengeSlugKey  ($blocking blocking, $warns warn)',
        );
        for (final issue in issues) {
          stdout.writeln(
            '        ${issue.severity.name.padRight(8)} '
            '${issue.code.padRight(24)} ${issue.location}: ${issue.message}',
          );
        }
      }
      stdout.writeln(
        '${challengeIssues.length} challenges · $challengeBlocking blocking · '
        '${challengesPassed ? 'PASS' : 'FAIL'}',
      );
    }
  }
  exit(report.passed && challengesPassed ? 0 : 1);
}
