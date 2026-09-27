import 'dart:io';

import 'package:content/src/library/challenge_source.dart';
import 'package:content/src/library/paths.dart';
import 'package:content/src/library/word_source.dart';
import 'package:content/src/model/challenge.dart';
import 'package:content/src/model/theme.dart';
import 'package:content/src/model/word.dart';

/// Everything a command needs from disk, loaded once.
final class LoadedLibrary {
  const LoadedLibrary({
    required this.paths,
    required this.taxonomy,
    required this.sources,
    required this.commonLemmas,
    this.challengeSources = const [],
  });

  final ContentPaths paths;
  final ThemeTaxonomy taxonomy;
  final List<WordSource> sources;
  final Set<String>? commonLemmas;
  final List<ChallengeSource> challengeSources;

  /// Words that build cleanly. Broken files are reported by `content:validate`,
  /// so the other commands simply skip them.
  List<Word> get words => [
    for (final source in sources)
      if (source.parseError == null)
        if (_tryParse(source.raw) case final Word word) word,
  ];

  /// Challenges that build cleanly, mirroring [words]. Empty until
  /// `content/challenges/*.yml` is authored (U6a/U6b).
  List<Challenge> get challenges => [
    for (final source in challengeSources)
      if (source.parseError == null)
        if (_tryParseChallenge(source.raw) case final Challenge challenge)
          challenge,
  ];

  static Word? _tryParse(Map<String, Object?> raw) {
    try {
      return Word.fromMap(raw);
    } on Object {
      return null;
    }
  }

  static Challenge? _tryParseChallenge(Map<String, Object?> raw) {
    try {
      return Challenge.fromMap(raw);
    } on Object {
      return null;
    }
  }
}

LoadedLibrary loadLibrary({
  String? root,
  String? onlySlug,
  String? onlyChallengeSlug,
}) {
  final paths = root == null ? ContentPaths.discover() : ContentPaths(root);
  return LoadedLibrary(
    paths: paths,
    taxonomy: ThemeTaxonomy.parse(File(paths.themesFile).readAsStringSync()),
    sources: loadWordSources(paths.wordsDir, onlySlug: onlySlug),
    commonLemmas: loadCommonLemmas(paths.commonLemmasFile),
    challengeSources: loadChallengeSources(
      paths.challengesDir,
      onlySlug: onlyChallengeSlug,
    ),
  );
}

Never fail(String message) {
  stderr.writeln('error: $message');
  exit(2);
}
