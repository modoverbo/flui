import 'package:content/src/library/challenge_source.dart';
import 'package:content/src/model/challenge.dart';
import 'package:content/src/validation/challenge_validators.dart';
import 'package:content/src/validation/issue.dart';

/// Mirrors `content/lib/src/validation/runner.dart`'s `ValidationReport` for
/// challenges: per-file issues keyed by slug, plus the library-wide pass
/// (unique slugs, diagnosis-slot coverage, training-mode coverage).
final class ChallengeValidationReport {
  const ChallengeValidationReport({
    required this.issuesBySlug,
    required this.libraryIssues,
    required this.challengeCount,
    required this.parsedCount,
  });

  final Map<String, List<Issue>> issuesBySlug;
  final List<Issue> libraryIssues;
  final int challengeCount;
  final int parsedCount;

  List<Issue> get allIssues => [
    for (final issues in issuesBySlug.values) ...issues,
    ...libraryIssues,
  ];

  int get blockingCount => allIssues.where((i) => i.isBlocking).length;

  int get warnCount => allIssues.where((i) => !i.isBlocking).length;

  bool get passed => blockingCount == 0;

  Map<String, Object?> toJson() => {
    'challenges': challengeCount,
    'parsed': parsedCount,
    'blocking': blockingCount,
    'warn': warnCount,
    'passed': passed,
    'byChallenge': {
      for (final entry in issuesBySlug.entries)
        entry.key: [for (final issue in entry.value) issue.toJson()],
    },
    'library': [for (final issue in libraryIssues) issue.toJson()],
  };

  /// Human report: one block per challenge, then the library-wide findings.
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
        '$parsedCount/$challengeCount challenges parsed · $blockingCount blocking · '
        '$warnCount warn · ${passed ? 'PASS' : 'FAIL'}',
      );
    return buffer.toString();
  }
}

/// Runs [ChallengeValidatorRegistry] over every loaded challenge source,
/// including the library-wide pass (unique slugs, diagnosis-slot coverage,
/// training-mode coverage) that U5b deferred until real content existed
/// (see that unit's own note in `content/lib/src/validation/challenge_validators.dart`).
final class ChallengeValidationRunner {
  const ChallengeValidationRunner();

  /// [includeLibraryPass] mirrors the word validator's
  /// `ValidationOptions.enableCatalogSimulation`: a `--challenge <slug>` run
  /// only loads that one file, so slot/mode coverage would spuriously fail
  /// on every slot and mode the single file does not cover. `--all` (the
  /// default) keeps it on.
  ChallengeValidationReport run(
    List<ChallengeSource> sources, {
    bool includeLibraryPass = true,
  }) {
    final issuesBySlug = <String, List<Issue>>{};
    final challenges = <Challenge>[];

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
      for (final validator in ChallengeValidatorRegistry.rawValidators) {
        issues.addAll(validator.validateRaw(source.slug, source.raw));
      }
      try {
        final challenge = Challenge.fromMap(source.raw);
        challenges.add(challenge);
        for (final validator
            in ChallengeValidatorRegistry.challengeValidators) {
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

    final libraryIssues = <Issue>[];
    if (includeLibraryPass) {
      for (final validator in ChallengeValidatorRegistry.libraryValidators) {
        libraryIssues.addAll(validator.validateChallengeLibrary(challenges));
      }
    }

    return ChallengeValidationReport(
      issuesBySlug: issuesBySlug,
      libraryIssues: libraryIssues,
      challengeCount: sources.length,
      parsedCount: challenges.length,
    );
  }
}
