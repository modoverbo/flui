import 'package:content/src/model/word.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';

/// Base of every validator, so the registry can describe the suite.
abstract class ContentValidator {
  const ContentValidator();

  /// Stable code, also the key used in reports and in `--json` output.
  String get code;

  /// One line describing what the validator refuses to let through.
  String get description;

  /// Severity of the issues it emits.
  Severity get severity;
}

/// Runs against the raw YAML map, before the word model exists.
abstract class RawWordValidator extends ContentValidator {
  const RawWordValidator();

  List<Issue> validateRaw(String slug, Map<String, Object?> raw);
}

/// Runs against one parsed word.
abstract class WordValidator extends ContentValidator {
  const WordValidator();

  List<Issue> validateWord(Word word, LibraryContext context);
}

/// Runs against the whole library at once.
abstract class LibraryValidator extends ContentValidator {
  const LibraryValidator();

  List<Issue> validateLibrary(LibraryContext context);
}
