import 'dart:io';

import 'package:content/src/library/paths.dart';
import 'package:content/src/library/word_source.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/runner.dart';
import 'package:test/test.dart';

import 'support/validation_harness.dart';

/// The two worked examples AUTHORING.md hands to a writing agent must pass the
/// suite. If a rule change breaks them, the brief is wrong and this fails.
void main() {
  // Two words cannot feed a theme for 90 days, so the catalog-scale simulation
  // is off here exactly as it is for `content:validate --word <slug>`.
  const options = ValidationOptions(enableCatalogSimulation: false);
  final runner = ValidationRunner(
    taxonomy: testTaxonomy,
    // The shipped frequency list, so the examples are held to the same
    // common-vocabulary bar an authoring agent will be held to.
    commonLemmas: loadCommonLemmas(ContentPaths.discover().commonLemmasFile),
    options: options,
  );

  test('both reference examples exist', () {
    expect(loadWordSources('examples'), hasLength(2));
  });

  test('the reference examples have no blocking issue', () async {
    final report = await runner.run(loadWordSources('examples'));

    expect(
      report.allIssues.where((i) => i.isBlocking),
      isEmpty,
      reason: report.format(),
    );
  });

  test('the reference examples raise no issue at all', () async {
    final report = await runner.run(loadWordSources('examples'));

    expect(report.allIssues, isEmpty, reason: report.format());
  });

  test('perspicaz stays identical to the canonical test fixture body', () {
    // Everything between `slug:` and `provenance:`: the two files differ only
    // in their header comment, sort_order, id and provenance.
    String body(String path) =>
        File(path)
            .readAsLinesSync()
            .skipWhile((line) => !line.startsWith('slug:'))
            .takeWhile((line) => !line.startsWith('provenance:'))
            .join('\n');

    expect(
      body('examples/perspicaz.yml'),
      body('test/support/valid_word.yml'),
    );
  });

  test(
    'AUTHORING.md points at both examples and at the self-check command',
    () {
      final brief = File('AUTHORING.md').readAsStringSync();

      expect(brief, contains('examples/perspicaz.yml'));
      expect(brief, contains('examples/matizar.yml'));
      expect(brief, contains('dart run content:validate --word <slug>'));
    },
  );
}
