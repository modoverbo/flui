import 'package:content/src/library/word_source.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/originality.dart';
import 'package:content/src/validation/registry.dart';
import 'package:content/src/validation/runner.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

WordSource sourceOf(String slug, Map<String, Object?> raw) =>
    WordSource(path: 'words/$slug.yml', slug: slug, raw: raw);

void main() {
  /// Single-word runs skip the catalog-scale scheduling simulation, exactly
  /// like `dart run content:validate --word <slug>`.
  const singleWord = ValidationOptions(enableCatalogSimulation: false);
  final runner = ValidationRunner(taxonomy: testTaxonomy, options: singleWord);

  test('the canonical word has no blocking issue', () async {
    final report = await runner.run([sourceOf('perspicaz', validWordMap())]);

    expect(
      report.allIssues.where((i) => i.isBlocking),
      isEmpty,
      reason: report.format(),
    );
    expect(report.passed, isTrue);
  });

  test('it still warns about the missing frequency list', () async {
    final report = await runner.run([sourceOf('perspicaz', validWordMap())]);

    expect(report.warnCount, 1);
    expect(report.allIssues.single.code, 'common_vocabulary');
  });

  test(
    'the catalog simulation is on by default and a lone word starves',
    () async {
      final report = await ValidationRunner(taxonomy: testTaxonomy).run([
        sourceOf('perspicaz', validWordMap()),
      ]);

      expect(
        report.libraryIssues.map((i) => i.code),
        contains('scheduling_simulation'),
      );
    },
  );

  test('a schema count failure still runs the rest of the suite', () async {
    final map = validWordMap();
    map['exercises'] = (map['exercises']! as List<Object?>).sublist(0, 3);
    final report = await runner.run([sourceOf('perspicaz', map)]);

    final codes = report.issuesBySlug['perspicaz']!.map((i) => i.code).toSet();
    expect(report.parsedCount, 1);
    expect(codes, contains('schema'));
    expect(codes, contains('exercise_count'));
  });

  test('a value the model cannot read is reported, not thrown', () async {
    final broken = validWordMap()..['register'] = 'formalote';
    final report = await runner.run([sourceOf('perspicaz', broken)]);

    expect(report.parsedCount, 0);
    expect(report.allIssues.map((i) => i.code), contains('model'));
  });

  test('a file name that disagrees with the slug is blocking', () async {
    final report = await runner.run([sourceOf('otro', validWordMap())]);

    expect(report.allIssues.map((i) => i.code), contains('file_name'));
  });

  test('a YAML parse error is reported, not thrown', () async {
    final report = await runner.run([
      const WordSource(
        path: 'words/roto.yml',
        slug: 'roto',
        raw: {},
        parseError: 'mapping values are not allowed here',
      ),
    ]);

    expect(report.allIssues.single.code, 'yaml');
    expect(report.passed, isFalse);
  });

  test('the JSON report carries every issue', () async {
    final report = await runner.run([sourceOf('perspicaz', validWordMap())]);
    final json = report.toJson();

    expect(json['words'], 1);
    expect(json['passed'], isTrue);
    expect((json['byWord']! as Map<String, Object?>).keys, ['perspicaz']);
  });

  test('every registered validator has a unique code and a description', () {
    final all = ValidatorRegistry.all(const OfflineFetcher());
    final codes = all.map((v) => v.code).toList();

    expect(codes.toSet(), hasLength(codes.length));
    for (final validator in all) {
      expect(validator.description, isNotEmpty, reason: validator.code);
    }
  });

  test('the registry ships 31 validators', () {
    expect(ValidatorRegistry.all(const OfflineFetcher()), hasLength(31));
  });
}
