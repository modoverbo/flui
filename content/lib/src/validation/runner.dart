import 'package:content/src/library/word_source.dart';
import 'package:content/src/model/theme.dart';
import 'package:content/src/model/word.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/originality.dart';
import 'package:content/src/validation/registry.dart';

final class ValidationReport {
  const ValidationReport({
    required this.issuesBySlug,
    required this.libraryIssues,
    required this.wordCount,
    required this.parsedCount,
  });

  final Map<String, List<Issue>> issuesBySlug;
  final List<Issue> libraryIssues;
  final int wordCount;
  final int parsedCount;

  List<Issue> get allIssues => [
    for (final issues in issuesBySlug.values) ...issues,
    ...libraryIssues,
  ];

  int get blockingCount => allIssues.where((i) => i.isBlocking).length;

  int get warnCount => allIssues.where((i) => !i.isBlocking).length;

  bool get passed => blockingCount == 0;

  /// Slugs with no blocking issue.
  List<String> get cleanSlugs => [
    for (final entry in issuesBySlug.entries)
      if (!entry.value.any((i) => i.isBlocking)) entry.key,
  ];

  Map<String, Object?> toJson() => {
    'words': wordCount,
    'parsed': parsedCount,
    'blocking': blockingCount,
    'warn': warnCount,
    'passed': passed,
    'byWord': {
      for (final entry in issuesBySlug.entries)
        entry.key: [for (final issue in entry.value) issue.toJson()],
    },
    'library': [for (final issue in libraryIssues) issue.toJson()],
  };

  /// Human report: one block per word, then the library-wide findings.
  String format() {
    final buffer = StringBuffer();
    final slugs = issuesBySlug.keys.toList()..sort();
    for (final slug in slugs) {
      final issues = issuesBySlug[slug]!;
      final blocking = issues.where((i) => i.isBlocking).length;
      final warns = issues.length - blocking;
      final mark = blocking == 0 ? (warns == 0 ? 'ok  ' : 'warn') : 'FAIL';
      buffer.writeln('$mark  $slug  ($blocking blocking, $warns warn)');
      for (final issue in issues) {
        buffer.writeln(
          '        ${issue.severity.name.padRight(8)} ${issue.code.padRight(24)} '
          '${issue.location}: ${issue.message}',
        );
      }
    }
    if (libraryIssues.isNotEmpty) {
      buffer.writeln('library');
      for (final issue in libraryIssues) {
        buffer.writeln(
          '        ${issue.severity.name.padRight(8)} ${issue.code.padRight(24)} '
          '${issue.slug.isEmpty ? issue.location : '${issue.slug} ${issue.location}'}: '
          '${issue.message}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln(
        '$parsedCount/$wordCount words parsed · $blockingCount blocking · '
        '$warnCount warn · ${passed ? 'PASS' : 'FAIL'}',
      );
    return buffer.toString();
  }
}

/// Runs the whole validator suite over a set of word files.
final class ValidationRunner {
  const ValidationRunner({
    required this.taxonomy,
    this.commonLemmas,
    this.options = const ValidationOptions(),
    this.fetcher = const OfflineFetcher(),
  });

  final ThemeTaxonomy taxonomy;
  final Set<String>? commonLemmas;
  final ValidationOptions options;
  final SearchFetcher fetcher;

  Future<ValidationReport> run(List<WordSource> sources) async {
    final issuesBySlug = <String, List<Issue>>{};
    final words = <Word>[];

    for (final source in sources) {
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
      for (final validator in ValidatorRegistry.rawValidators) {
        issues.addAll(validator.validateRaw(source.slug, source.raw));
      }
      if (source.raw['slug'] != source.slug) {
        issues.add(
          Issue(
            code: 'file_name',
            severity: Severity.blocking,
            slug: source.slug,
            location: 'slug',
            message:
                'the file is named ${source.slug}.yml but declares '
                'slug "${source.raw['slug']}"',
          ),
        );
      }
      // A schema issue does not stop the rest of the suite: a file with three
      // exercises instead of eight still has answer leakage, brand and
      // typography to answer for, and one run must show every gap at once.
      try {
        words.add(Word.fromMap(source.raw));
      } on FormatException catch (error) {
        issues.add(
          Issue(
            code: 'model',
            severity: Severity.blocking,
            slug: source.slug,
            location: 'file',
            message: 'could not build the word model: ${error.message}',
          ),
        );
      }
      issuesBySlug[source.slug] = issues;
    }

    final context = LibraryContext(
      words: words,
      taxonomy: taxonomy,
      commonLemmas: commonLemmas,
      options: options,
    );

    for (final word in words) {
      final issues = issuesBySlug.putIfAbsent(word.slug, () => []);
      for (final validator in ValidatorRegistry.wordValidators) {
        issues.addAll(validator.validateWord(word, context));
      }
      for (final validator in ValidatorRegistry.asyncValidators(fetcher)) {
        issues.addAll(await validator.validateWordAsync(word, context));
      }
    }

    final libraryIssues = <Issue>[];
    for (final validator in ValidatorRegistry.libraryValidators) {
      libraryIssues.addAll(validator.validateLibrary(context));
    }

    return ValidationReport(
      issuesBySlug: issuesBySlug,
      libraryIssues: libraryIssues,
      wordCount: sources.length,
      parsedCount: words.length,
    );
  }
}
