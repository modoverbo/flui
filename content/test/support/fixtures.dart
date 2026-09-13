import 'dart:io';

import 'package:content/src/model/word.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:path/path.dart' as p;

/// Directory of this test-support folder, independent of the cwd `dart test`
/// happens to use.
final String supportDir = p.join(Directory.current.path, 'test', 'support');

String _readFixture(String name) =>
    File(p.join(supportDir, name)).readAsStringSync();

/// The canonical word that passes every validator, as a plain Dart map.
Map<String, Object?> validWordMap() =>
    deepConvertYaml(loadYamlDocumentValue(_readFixture('valid_word.yml')))!
        as Map<String, Object?>;

/// The canonical word, parsed.
Word validWord() => Word.fromMap(validWordMap());

/// [validWordMap] with one top-level key replaced.
Map<String, Object?> wordMapWith(Map<String, Object?> overrides) =>
    validWordMap()..addAll(overrides);

/// Deep copy of the canonical map so a mutation in one test cannot leak.
Map<String, Object?> mutableExercises(Map<String, Object?> map) =>
    (map['exercises']! as List<Object?>).cast<Map<String, Object?>>().first;
