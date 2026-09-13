import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the toolkit's data lives, independent of the caller's cwd.
final class ContentPaths {
  ContentPaths(this.root);

  /// Walks up from [start] (default: cwd) until it finds the `content`
  /// package root, so `dart run content:validate` works from anywhere in the
  /// repository.
  factory ContentPaths.discover([String? start]) {
    var dir = Directory(p.absolute(start ?? Directory.current.path));
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync() &&
          pubspec.readAsStringSync().startsWith(
            '# flui content authoring toolkit',
          )) {
        return ContentPaths(dir.path);
      }
      final candidate = Directory(p.join(dir.path, 'content'));
      if (File(p.join(candidate.path, 'themes.yml')).existsSync()) {
        return ContentPaths(candidate.path);
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError(
          'could not find the content package root from ${start ?? Directory.current.path}',
        );
      }
      dir = parent;
    }
  }

  final String root;

  String get wordsDir => p.join(root, 'words');

  String get themesFile => p.join(root, 'themes.yml');

  String get schemaFile => p.join(root, 'schema', 'word.schema.json');

  String get dataDir => p.join(root, 'data');

  String get commonLemmasFile => p.join(dataDir, 'common_lemmas_es.txt');

  String get candidatesFile => p.join(dataDir, 'candidates.csv');

  String get seedPreambleFile => p.join(root, 'templates', 'seed_preamble.sql');

  String get gateDir => p.join(root, 'gate');

  /// `<repo>/supabase/seed.sql`, the emitter's default target.
  String get defaultSeedFile => p.join(p.dirname(root), 'supabase', 'seed.sql');
}
