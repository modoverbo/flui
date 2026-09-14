import 'package:content/src/model/word.dart';
import 'package:content/src/validation/structural.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

void main() {
  group('SlugMatchesLemmaValidator', () {
    const validator = SlugMatchesLemmaValidator();

    test('accepts a slug equal to the normalized lemma', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects a slug that is not the normalized lemma', () {
      final word = wordFrom({'slug': 'perspicacia'});
      expect(runWord(validator, word), hasLength(1));
    });

    test('accepts an accented lemma normalized into the slug', () {
      final word = wordFrom({'lemma': 'perspicáz', 'slug': 'perspicaz'});
      expect(runWord(validator, word), isEmpty);
    });
  });

  group('SyllablesValidator', () {
    const validator = SyllablesValidator();

    test('accepts syllables that concatenate to the lemma', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('is accent insensitive', () {
      final word = wordFrom({
        'lemma': 'matizó',
        'slug': 'matizo',
        'syllables': ['ma', 'ti', 'zo'],
        'stressed_syllable': 3,
      });
      expect(runWord(validator, word), isEmpty);
    });

    test('rejects syllables that do not rebuild the lemma', () {
      final word = wordFrom({
        'syllables': ['pers', 'pi', 'cazz'],
      });
      expect(runWord(validator, word).map((i) => i.code), ['syllables']);
    });

    test('rejects a stressed syllable out of range', () {
      final word = wordFrom({'stressed_syllable': 4});
      expect(runWord(validator, word), hasLength(1));
    });

    test('rejects a stressed syllable below one', () {
      final word = wordFrom({'stressed_syllable': 0});
      expect(runWord(validator, word), hasLength(1));
    });
  });

  group('ExerciseCountValidator', () {
    const validator = ExerciseCountValidator();

    /// The canonical word cut down to [count] exercises, positions renumbered
    /// the way `content:prune` leaves them.
    Word pruned(int count) {
      final map = validWordMap();
      final exercises = (map['exercises']! as List<Object?>)
          .sublist(0, count)
          .cast<Map<String, Object?>>();
      for (var i = 0; i < exercises.length; i++) {
        exercises[i] = {...exercises[i], 'position': i + 1};
      }
      return Word.fromMap(map..['exercises'] = exercises);
    }

    test('accepts exactly eight exercises with one blank each', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('accepts seven exercises left by a gate prune', () {
      expect(runWord(validator, pruned(7)), isEmpty);
    });

    test('accepts the six-exercise floor', () {
      expect(runWord(validator, pruned(6)), isEmpty);
    });

    test('rejects five exercises, below the floor', () {
      expect(runWord(validator, pruned(5)), hasLength(1));
    });

    test('rejects nine exercises, above the authored count', () {
      final map = validWordMap();
      final exercises = (map['exercises']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .toList();
      exercises.add({...exercises.first, 'position': 9});
      expect(
        runWord(validator, Word.fromMap(map..['exercises'] = exercises)),
        isNotEmpty,
      );
    });

    test('rejects a pruned set whose positions were not renumbered', () {
      final map = validWordMap();
      final exercises = (map['exercises']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .toList()
        ..removeAt(2);
      expect(
        runWord(validator, Word.fromMap(map..['exercises'] = exercises)),
        hasLength(1),
      );
    });

    test('rejects a sentence without a blank', () {
      final word = wordWithExercise(0, {'sentence': 'Una frase sin hueco.'});
      expect(runWord(validator, word), hasLength(1));
    });

    test('rejects a sentence with two blanks', () {
      final word = wordWithExercise(0, {
        'sentence': 'Una frase con {{blank}} y otro {{blank}} aquí.',
      });
      expect(runWord(validator, word), hasLength(1));
    });

    test('rejects duplicated exercise positions', () {
      final map = validWordMap();
      final exercises = (map['exercises']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .toList();
      exercises[1] = {...exercises[1], 'position': 1};
      map['exercises'] = exercises;
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });
  });

  group('OptionSetValidator', () {
    const validator = OptionSetValidator();

    test('accepts three options with exactly one correct', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects two options', () {
      final map = validWordMap();
      final exercises = map['exercises']! as List<Object?>;
      final first = Map<String, Object?>.from(
        exercises.first! as Map<String, Object?>,
      );
      first['options'] = (first['options']! as List<Object?>).sublist(0, 2);
      exercises[0] = first;
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });

    test('rejects two correct options', () {
      final word = wordWithOption(0, 0, {
        'is_correct': true,
        'distractor_type': null,
        'why_not': null,
        'hint_specific': null,
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects duplicated option texts', () {
      final word = wordWithOption(0, 0, {'text': 'perspicaz'});
      expect(
        runWord(validator, word).map((i) => i.message).join(),
        contains('duplicate'),
      );
    });

    test('rejects duplicated option positions', () {
      final word = wordWithOption(0, 0, {'position': 2});
      expect(runWord(validator, word), isNotEmpty);
    });
  });

  group('DistractorFieldsValidator', () {
    const validator = DistractorFieldsValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects a correct option that carries distractor data', () {
      final word = wordWithOption(0, 1, {'distractor_type': 'paronym'});
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a distractor without why_not', () {
      final word = wordWithOption(0, 0, {'why_not': null});
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a distractor without hint_specific', () {
      final word = wordWithOption(0, 0, {'hint_specific': null});
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a distractor without a type', () {
      final word = wordWithOption(0, 0, {'distractor_type': null});
      expect(runWord(validator, word), isNotEmpty);
    });
  });

  group('DistractorTypeCoverageValidator', () {
    const validator = DistractorTypeCoverageValidator();

    test('accepts a word with paronym and register distractors', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects a word with no register distractor', () {
      final map = validWordMap();
      for (final exercise
          in (map['exercises']! as List<Object?>)
              .cast<Map<String, Object?>>()) {
        for (final option
            in (exercise['options']! as List<Object?>)
                .cast<Map<String, Object?>>()) {
          if (option['distractor_type'] == 'register') {
            option['distractor_type'] = 'near_synonym';
          }
        }
      }
      expect(runWord(validator, Word.fromMap(map)), hasLength(1));
    });
  });

  group('ReadingSetValidator', () {
    const validator = ReadingSetValidator();

    test('accepts three readings in distinct scenes', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects two readings', () {
      final map = validWordMap();
      map['readings'] = (map['readings']! as List<Object?>).sublist(0, 2);
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });

    test('rejects repeated scenes', () {
      final map = validWordMap();
      final readings = (map['readings']! as List<Object?>)
          .cast<Map<String, Object?>>();
      readings[1]['scene'] = 'trabajo';
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });

    test('rejects a single conversation type', () {
      final map = validWordMap();
      for (final reading
          in (map['readings']! as List<Object?>).cast<Map<String, Object?>>()) {
        reading['conversation_type'] = 'practica';
      }
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });
  });

  group('ConfusionValidator', () {
    const validator = ConfusionValidator();

    test('accepts confusions with a difference and a memory trick', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects an empty confusion list', () {
      final word = wordFrom({'confusions': <Object?>[]});
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects when no confusion carries a memory trick', () {
      final map = validWordMap();
      for (final c
          in (map['confusions']! as List<Object?>)
              .cast<Map<String, Object?>>()) {
        c['memory_trick'] = null;
      }
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });

    test('rejects a confusion pointing at the word itself', () {
      final map = validWordMap();
      (map['confusions']! as List<Object?>)
              .cast<Map<String, Object?>>()[0]['confused_with'] =
          'perspicaz';
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });
  });

  group('ReplacesValidator', () {
    const validator = ReplacesValidator();

    test('accepts two replacement pairs', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects a single pair', () {
      final map = validWordMap();
      map['replaces'] = (map['replaces']! as List<Object?>).sublist(0, 1);
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });

    test('accepts a conjugated "after" of a verb lemma', () {
      final map = validWordMap()
        ..['lemma'] = 'zanjar'
        ..['slug'] = 'zanjar'
        ..['part_of_speech'] = 'verbo'
        ..['syllables'] = ['zan', 'jar']
        ..['stressed_syllable'] = 2
        ..['replaces'] = [
          {'before': 'Cerremos el tema', 'after': 'Zanjemos el tema'},
          {
            'before': 'Ya, se acabó la discusión',
            'after': 'Con esto zanjamos la discusión',
          },
        ];
      expect(runWord(validator, Word.fromMap(map)), isEmpty);
    });

    test('rejects an after phrase that does not use the word', () {
      final map = validWordMap();
      (map['replaces']! as List<Object?>)
              .cast<Map<String, Object?>>()[0]['after'] =
          'Es muy listo';
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });
  });
}
