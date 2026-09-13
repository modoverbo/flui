import 'dart:convert';
import 'dart:io';

import 'package:content/src/validation/schema.dart';
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

  test('rejects a slug that is not kebab-case', () {
    expect(
      validator.validateRaw(
        'Perspicaz!',
        validWordMap()..['slug'] = 'Perspicaz!',
      ),
      isNotEmpty,
    );
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
