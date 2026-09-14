import 'dart:convert';
import 'dart:io';

import 'package:content/src/validation/schema.dart';
import 'package:content/src/validation/structural.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  const validator = SchemaConformanceValidator();

  test('accepts the canonical word file', () {
    expect(validator.validateRaw('perspicaz', validWordMap()), isEmpty);
  });

  test('reports every missing required key', () {
    final issues = validator.validateRaw('x', <String, Object?>{});
    final missing = issues.map((i) => i.location).toSet();
    expect(missing, containsAll(SchemaConformanceValidator.requiredKeys));
  });

  test('rejects an unknown top-level key', () {
    final issues = validator.validateRaw(
      'perspicaz',
      validWordMap()..['nope'] = 1,
    );
    expect(issues.map((i) => i.location), contains('nope'));
  });

  test('rejects a wrong scalar type', () {
    final issues = validator.validateRaw(
      'perspicaz',
      validWordMap()..['pedantry_risk'] = 'uno',
    );
    expect(issues, isNotEmpty);
  });

  test('rejects an out-of-range pedantry risk', () {
    expect(
      validator.validateRaw('perspicaz', validWordMap()..['pedantry_risk'] = 4),
      isNotEmpty,
    );
  });

  test('rejects an unknown enum value', () {
    expect(
      validator.validateRaw('perspicaz', validWordMap()..['status'] = 'listo'),
      isNotEmpty,
    );
  });

  test('rejects a malformed nested option', () {
    final map = validWordMap();
    final exercises = (map['exercises']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final options = (exercises.first['options']! as List<Object?>)
        .cast<Map<String, Object?>>();
    options.first.remove('text');
    expect(validator.validateRaw('perspicaz', map), isNotEmpty);
  });

  test('accepts a kebab-case semantic_set_id', () {
    expect(
      validator.validateRaw(
        'perspicaz',
        validWordMap()..['semantic_set_id'] = 'fuerza-de-la-afirmacion',
      ),
      isEmpty,
    );
  });

  test('accepts a null semantic_set_id', () {
    expect(
      validator.validateRaw(
        'perspicaz',
        validWordMap()..['semantic_set_id'] = null,
      ),
      isEmpty,
    );
  });

  test('rejects a semantic_set_id that is not kebab-case', () {
    expect(
      validator.validateRaw(
        'perspicaz',
        validWordMap()..['semantic_set_id'] = 'Fuerza De La Afirmación',
      ),
      isNotEmpty,
    );
  });

  test('rejects a slug that is not kebab-case', () {
    expect(
      validator.validateRaw(
        'Perspicaz!',
        validWordMap()..['slug'] = 'Perspicaz!',
      ),
      isNotEmpty,
    );
  });

  test('accepts a word pruned down to the six-exercise floor', () {
    final map = validWordMap();
    map['exercises'] = (map['exercises']! as List<Object?>).sublist(0, 6);
    expect(validator.validateRaw('perspicaz', map), isEmpty);
  });

  test('rejects a word with five exercises', () {
    final map = validWordMap();
    map['exercises'] = (map['exercises']! as List<Object?>).sublist(0, 5);
    expect(validator.validateRaw('perspicaz', map), isNotEmpty);
  });

  test('rejects a word with nine exercises', () {
    final map = validWordMap();
    final exercises = (map['exercises']! as List<Object?>).toList()
      ..add((map['exercises']! as List<Object?>).first);
    expect(
      validator.validateRaw('perspicaz', map..['exercises'] = exercises),
      isNotEmpty,
    );
  });

  test('the shipped JSON schema declares the same exercise bounds', () {
    final schema =
        jsonDecode(File('schema/word.schema.json').readAsStringSync())
            as Map<String, Object?>;
    final exercises =
        (schema['properties']! as Map<String, Object?>)['exercises']!
            as Map<String, Object?>;

    expect(exercises['minItems'], minExerciseCount);
    expect(exercises['maxItems'], authoredExerciseCount);
  });

  test('the shipped JSON schema declares the same required keys', () {
    final schema = jsonDecode(
      File('schema/word.schema.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final required = (schema['required']! as List<Object?>)
        .cast<String>()
        .toSet();
    expect(required, SchemaConformanceValidator.requiredKeys);
  });

  test('the shipped JSON schema describes every property the model reads', () {
    final schema = jsonDecode(
      File('schema/word.schema.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final properties = (schema['properties']! as Map<String, Object?>).keys
        .toSet();
    expect(properties, SchemaConformanceValidator.knownKeys);
  });
}
