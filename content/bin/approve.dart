import 'dart:io';

import 'package:args/args.dart';
import 'package:content/src/cli/approve.dart';
import 'package:content/src/cli/common.dart';
import 'package:content/src/model/word_yaml.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:path/path.dart' as p;

/// `dart run content:approve [--word <slug>] [--all]`
///
/// Promotes `gated` words to `approved`, which is what `content:emit` writes
/// into the seed. There is no human sign-off between the gate and this
/// command; production telemetry is what unpublishes a bad word. See GATE.md.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('word', help: 'Promote a single word by slug.')
    ..addFlag('all', help: 'Promote every gated word.')
    ..addOption('root', help: 'Path to the content package.')
    ..addFlag('dry-run', help: 'Report without touching the word files.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout
      ..writeln('dart run content:approve [--word <slug>] [--all]')
      ..writeln(parser.usage);
    return;
  }

  final slug = args.option('word');
  if (slug == null && !args.flag('all')) {
    fail('pass --word <slug> or --all; promoting the catalog is not a default');
  }
  if (slug != null && args.flag('all')) {
    fail('pass either --word <slug> or --all, not both');
  }

  final library = loadLibrary(root: args.option('root'));
  final statusBySlug = <String, String>{
    for (final source in library.sources)
      if (source.parseError == null)
        source.slug: source.raw['status'] as String? ?? 'unreadable',
  };
  if (slug != null && !statusBySlug.containsKey(slug)) {
    fail('no word file named $slug.yml in ${library.paths.wordsDir}');
  }

  final plan = planPromotion(statusBySlug, onlySlug: slug);

  for (final entry in plan.skipped.entries) {
    // Only ever mention the word the caller asked about: over the whole
    // catalog "skipped" is every draft there is, which is not news.
    if (slug != null) stdout.writeln('skipped  ${entry.key}: ${entry.value}');
  }
  for (final promoted in plan.promoted) {
    stdout.writeln('approved $promoted');
    if (args.flag('dry-run')) continue;
    final file = File(p.join(library.paths.wordsDir, '$promoted.yml'));
    final map =
        loadYamlAsPlain(file.readAsStringSync())! as Map<String, Object?>;
    map['status'] = 'approved';
    file.writeAsStringSync(writeWordYaml(map));
  }

  stdout.writeln(
    '${plan.promoted.length} promoted to approved'
    '${plan.skipped.isEmpty ? '' : ', ${plan.skipped.length} left alone'}',
  );
}
