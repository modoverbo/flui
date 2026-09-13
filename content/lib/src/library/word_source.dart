import 'dart:io';

import 'package:content/src/model/yaml_map.dart';
import 'package:path/path.dart' as p;

/// One `content/words/<slug>.yml` file, loaded but not yet validated.
final class WordSource {
  const WordSource({
    required this.path,
    required this.slug,
    required this.raw,
    this.parseError,
  });

  final String path;

  /// Slug taken from the file name, so a mismatch with the `slug` field is
  /// itself reportable.
  final String slug;
  final Map<String, Object?> raw;
  final String? parseError;
}

/// Loads every word file of a directory, sorted by slug for determinism.
List<WordSource> loadWordSources(String wordsDir, {String? onlySlug}) {
  final dir = Directory(wordsDir);
  if (!dir.existsSync()) return const [];
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sources = <WordSource>[];
  for (final file in files) {
    final slug = p.basenameWithoutExtension(file.path);
    if (onlySlug != null && slug != onlySlug) continue;
    try {
      final parsed = loadYamlAsPlain(file.readAsStringSync());
      if (parsed is! Map<String, Object?>) {
        sources.add(
          WordSource(
            path: file.path,
            slug: slug,
            raw: const {},
            parseError: 'the file is not a YAML mapping',
          ),
        );
        continue;
      }
      sources.add(WordSource(path: file.path, slug: slug, raw: parsed));
    } on Object catch (error) {
      sources.add(
        WordSource(
          path: file.path,
          slug: slug,
          raw: const {},
          parseError: '$error',
        ),
      );
    }
  }
  return sources;
}

/// The top-N Spanish lemma list, or null when it has not been built yet.
Set<String>? loadCommonLemmas(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final lemmas = <String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    lemmas.add(trimmed.split(RegExp(r'\s|,|;')).first.toLowerCase());
  }
  return lemmas.isEmpty ? null : lemmas;
}
