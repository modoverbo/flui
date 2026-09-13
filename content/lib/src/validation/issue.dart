/// A validator finding.
///
/// `blocking` issues fail `dart run content:validate` (non-zero exit); `warn`
/// issues are printed and counted but never block, and are used only where the
/// check depends on data the repository does not ship yet.
enum Severity { blocking, warn }

final class Issue {
  const Issue({
    required this.code,
    required this.severity,
    required this.slug,
    required this.location,
    required this.message,
  });

  /// Stable identifier of the validator that produced the issue.
  final String code;
  final Severity severity;

  /// Word slug, or an empty string for library-wide findings.
  final String slug;

  /// Dotted path inside the word file, e.g. `exercises[3].options[2].why_not`.
  final String location;
  final String message;

  bool get isBlocking => severity == Severity.blocking;

  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    'slug': slug,
    'location': location,
    'message': message,
  };

  @override
  String toString() =>
      '[${severity.name}] $code ${slug.isEmpty ? '' : '$slug '}$location: $message';
}
