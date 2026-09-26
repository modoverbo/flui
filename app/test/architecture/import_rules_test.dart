import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// String-scan architecture test (design §2 "Rules"). No analyzer package
// dependency: a plain regex over `import` lines is enough to keep these
// directories honest, and keeps this test itself dependency-free.
//
// Scope grows as later units land: `core/mic` does not exist until U23b, so
// its checks are skipped (not failed) while the directory is absent.
void main() {
  group('features/training/domain stays pure', () {
    test('imports only Dart SDK/meta/freezed_annotation/core-date/core-error/ '
        'speaking-domain/vocabulary-domain', () {
      final allowedPrefixes = [
        'dart:',
        'package:meta/',
        'package:freezed_annotation/',
        'package:flui/core/date/',
        'package:flui/core/error/',
        'package:flui/features/speaking/domain/',
        'package:flui/features/vocabulary/domain/',
        'package:flui/features/training/domain/',
      ];
      final violations = <String>[
        for (final file in _dartFiles(
          Directory('lib/features/training/domain'),
        ))
          for (final import in _importsOf(file))
            if (!allowedPrefixes.any(import.startsWith))
              '${file.path}: $import',
      ];
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('features/speaking/domain never imports training', () {
    test('training owns BehaviorCode; speaking never reads it back', () {
      final violations = <String>[
        for (final file in _dartFiles(
          Directory('lib/features/speaking/domain'),
        ))
          for (final import in _importsOf(file))
            if (import.contains('features/training')) '${file.path}: $import',
      ];
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('core/audio and core/mic stay pure except declared exceptions', () {
    test('no Flutter/Riverpod/Supabase/record/just_audio import outside '
        'the providers/data/presentation exceptions', () {
      const forbidden = [
        'package:flutter/',
        'package:flutter_riverpod',
        'package:supabase_flutter',
        'package:record',
        'package:just_audio',
      ];
      bool isForbidden(String import) => forbidden.any(import.startsWith);

      final pureFiles = <File>[
        // core/audio/*.dart except the Riverpod wiring file.
        ..._dartFiles(
          Directory('lib/core/audio'),
          recursive: false,
        ).where((f) => _posix(f.path) != 'lib/core/audio/audio_providers.dart'),
        // core/audio/application/** (HoldToRecord and friends) is pure.
        ..._dartFiles(Directory('lib/core/audio/application')),
        // core/mic/*.dart except its Riverpod wiring file, once U23b lands.
        if (Directory('lib/core/mic').existsSync())
          ..._dartFiles(
            Directory('lib/core/mic'),
            recursive: false,
          ).where((f) => _posix(f.path) != 'lib/core/mic/mic_providers.dart'),
      ];

      final violations = <String>[
        for (final file in pureFiles)
          for (final import in _importsOf(file))
            if (isForbidden(import)) '${file.path}: $import',
      ];
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}

String _posix(String path) => path.replaceAll(r'\', '/');

/// `.dart` files directly under [dir], or recursively when [recursive].
/// Never fails when [dir] does not exist yet (a later unit's directory).
List<File> _dartFiles(Directory dir, {bool recursive = true}) {
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: recursive)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

final _importPattern = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// The `import '...'` targets in [file] (never `export`/`part`).
List<String> _importsOf(File file) => [
  for (final match in _importPattern.allMatches(file.readAsStringSync()))
    match.group(1)!,
];
