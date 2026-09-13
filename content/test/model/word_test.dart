import 'package:content/src/model/word.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  group('Word.fromMap', () {
    test('reads every authored field of a valid word', () {
      final word = Word.fromMap(validWordMap());

      expect(word.schemaVersion, 1);
      expect(word.slug, 'perspicaz');
      expect(word.status, WordStatus.approved);
      expect(word.lemma, 'perspicaz');
      expect(word.partOfSpeech, PartOfSpeech.adjetivo);
      expect(word.syllables, ['pers', 'pi', 'caz']);
      expect(word.stressedSyllable, 3);
      expect(word.ipaLatam, '[pers.piˈkas]');
      expect(word.register, Register.neutral);
      expect(word.pedantryRisk, 1);
      expect(word.collocations, hasLength(2));
      expect(word.replaces.first.before, 'Es muy listo');
      expect(word.replaces.first.after, 'Es muy perspicaz');
      expect(word.family, ['perspicacia', 'perspicazmente']);
      expect(word.themes.single.slug, 'reuniones');
      expect(word.themes.single.relevance, 3);
      expect(word.tags.comodin, ['listo']);
      expect(word.tags.canal, 'hablado');
      expect(word.confusions.first.confusedWith, 'suspicaz');
      expect(word.exercises, hasLength(8));
      expect(word.readings, hasLength(3));
    });

    test('reads exercise options with their distractor data', () {
      final word = Word.fromMap(validWordMap());
      final options = word.exercises.first.options;

      expect(options, hasLength(3));
      expect(options.where((o) => o.isCorrect), hasLength(1));
      final correct = options.firstWhere((o) => o.isCorrect);
      expect(correct.distractorType, isNull);
      expect(correct.whyNot, isNull);
      final distractor = options.firstWhere((o) => !o.isCorrect);
      expect(distractor.distractorType, DistractorType.paronym);
      expect(distractor.whyNot, isNotEmpty);
      expect(distractor.hintSpecific, isNotEmpty);
    });

    test('reads readings with scene and conversation type', () {
      final reading = Word.fromMap(validWordMap()).readings.first;

      expect(reading.scene, Scene.trabajo);
      expect(reading.conversationType, ConversationType.practica);
      expect(reading.position, 1);
    });

    test('treats metrics and provenance as optional', () {
      final map = validWordMap()
        ..remove('metrics')
        ..remove('provenance');

      final word = Word.fromMap(map);

      expect(word.metrics, isNull);
      expect(word.provenance, isNull);
    });

    test('keeps persistence identity when present', () {
      final word = Word.fromMap(validWordMap());

      expect(word.id, 'a0000000-0000-4000-8000-000000000001');
      expect(word.sortOrder, 1);
    });

    test('rejects an unknown enum value', () {
      final map = validWordMap()..['register'] = 'formalote';

      expect(() => Word.fromMap(map), throwsFormatException);
    });
  });

  group('Word.correctOptionOf', () {
    test('returns the single correct option of an exercise', () {
      final word = Word.fromMap(validWordMap());

      expect(word.exercises.first.correctOption.isCorrect, isTrue);
      expect(word.exercises.first.distractors, hasLength(2));
    });
  });

  group('deepConvertYaml', () {
    test('turns YamlMap and YamlList into plain Dart collections', () {
      final converted = deepConvertYaml(
        loadYamlDocumentValue('a: [1, {b: c}]'),
      );

      expect(converted, isA<Map<String, Object?>>());
      final map = converted! as Map<String, Object?>;
      expect(map['a'], isA<List<Object?>>());
      expect((map['a']! as List<Object?>)[1], isA<Map<String, Object?>>());
    });
  });
}
