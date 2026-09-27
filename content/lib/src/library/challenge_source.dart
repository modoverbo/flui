import 'dart:io';

import 'package:content/src/model/yaml_map.dart';
import 'package:path/path.dart' as p;

/// One `content/challenges/<slug>.yml` file, loaded but not yet validated.
/// Mirrors `content/lib/src/library/word_source.dart`'s `WordSource`.
final class ChallengeSource {
  const ChallengeSource({
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

/// Loads every challenge file of a directory, sorted by slug for
/// determinism. Returns an empty list when the directory does not exist
/// yet, so the emitter/validator work before any challenge is authored.
List<ChallengeSource> loadChallengeSources(
  String challengesDir, {
  String? onlySlug,
}) {
  final dir = Directory(challengesDir);
  if (!dir.existsSync()) return const [];
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sources = <ChallengeSource>[];
  for (final file in files) {
    final slug = p.basenameWithoutExtension(file.path);
    if (onlySlug != null && slug != onlySlug) continue;
    try {
      final parsed = loadYamlAsPlain(file.readAsStringSync());
      if (parsed is! Map<String, Object?>) {
        sources.add(
          ChallengeSource(
            path: file.path,
            slug: slug,
            raw: const {},
            parseError: 'the file is not a YAML mapping',
          ),
        );
        continue;
      }
      sources.add(ChallengeSource(path: file.path, slug: slug, raw: parsed));
    } on Object catch (error) {
      sources.add(
        ChallengeSource(
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
