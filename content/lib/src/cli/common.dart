import 'dart:io';

import 'package:content/src/library/paths.dart';
import 'package:content/src/library/word_source.dart';
import 'package:content/src/model/theme.dart';
import 'package:content/src/model/word.dart';

/// Everything a command needs from disk, loaded once.
final class LoadedLibrary {
  const LoadedLibrary({
    required this.paths,
    required this.taxonomy,
    required this.sources,
    required this.commonLemmas,
  });

  final ContentPaths paths;
  final ThemeTaxonomy taxonomy;
  final List<WordSource> sources;
  final Set<String>? commonLemmas;

  /// Words that build cleanly. Broken files are reported by `content:validate`,
  /// so the other commands simply skip them.
  List<Word> get words => [
    for (final source in sources)
      if (source.parseError == null)
        if (_tryParse(source.raw) case final Word word) word,
  ];

  static Word? _tryParse(Map<String, Object?> raw) {
    try {
      return Word.fromMap(raw);
    } on Object {
      return null;
    }
  }
}

LoadedLibrary loadLibrary({String? root, String? onlySlug}) {
  final paths = root == null ? ContentPaths.discover() : ContentPaths(root);
  return LoadedLibrary(
    paths: paths,
    taxonomy: ThemeTaxonomy.parse(File(paths.themesFile).readAsStringSync()),
    sources: loadWordSources(paths.wordsDir, onlySlug: onlySlug),
    commonLemmas: loadCommonLemmas(paths.commonLemmasFile),
  );
}

Never fail(String message) {
  stderr.writeln('error: $message');
  exit(2);
}
