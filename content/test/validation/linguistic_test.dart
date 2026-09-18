import 'package:content/src/model/word.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/linguistic.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

/// Replaces the first exercise wholesale: sentence, hint and three options.
Word exerciseWith({
  required String sentence,
  required String hintGeneral,
  required String explanation,
  required String correct,
  String partOfSpeech = 'adjetivo',
  List<String> distractors = const ['equivocada', 'errónea'],
}) {
  final map = validWordMap();
  map['part_of_speech'] = partOfSpeech;
  final exercises = (map['exercises']! as List<Object?>)
      .cast<Map<String, Object?>>();
  exercises[0] = {
    'position': 1,
    'sentence': sentence,
    'hint_general': hintGeneral,
    'explanation': explanation,
    'options': [
      {'position': 1, 'text': correct, 'is_correct': true},
      for (var i = 0; i < distractors.length; i++)
        {
          'position': i + 2,
          'text': distractors[i],
          'is_correct': false,
          'distractor_type': 'near_synonym',
          'why_not': 'No encaja en esta frase.',
          'hint_specific': 'Piensa en lo que hace esa persona.',
        },
    ],
  };
  return Word.fromMap(map);
}

void main() {
  group('AgreementValidator', () {
    const validator = AgreementValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('accepts an invariable adjective after a feminine determiner', () {
      final word = exerciseWith(
        sentence: 'Hizo una pregunta tan {{blank}} que nadie supo contestar.',
        hintGeneral: 'Dio justo en el punto que nadie había mirado.',
        explanation: 'Perspicaz. No encaja equivocada ni errónea.',
        correct: 'perspicaz',
      );
      expect(runWord(validator, word), isEmpty);
    });

    test('rejects a masculine answer under a feminine determiner', () {
      final word = exerciseWith(
        sentence: 'Hizo una pregunta tan {{blank}} que nadie supo contestar.',
        hintGeneral: 'Dio justo en el punto que nadie había mirado.',
        explanation: 'Perspicuo. No encaja equivocada ni errónea.',
        correct: 'perspicuo',
      );
      expect(runWord(validator, word).map((i) => i.code), ['agreement']);
    });

    test('rejects a singular answer under a plural determiner', () {
      final word = exerciseWith(
        sentence: 'Los datos {{blank}} convencieron al comité en dos minutos.',
        hintGeneral: 'Los datos no dejaron ninguna duda.',
        explanation: 'Contundentes. No encaja equivocada ni errónea.',
        correct: 'contundente',
      );
      expect(runWord(validator, word), hasLength(1));
    });

    test('accepts the plural answer under a plural determiner', () {
      final word = exerciseWith(
        sentence: 'Los datos {{blank}} convencieron al comité en dos minutos.',
        hintGeneral: 'Los datos no dejaron ninguna duda.',
        explanation: 'Contundentes. No encaja equivocada ni errónea.',
        correct: 'contundentes',
      );
      expect(runWord(validator, word), isEmpty);
    });

    test(
      'rejects a verb that does not agree with an explicit subject pronoun',
      () {
        final word = exerciseWith(
          sentence: 'Nosotros {{blank}} el tema en la reunión del lunes.',
          hintGeneral: 'Pusimos el tema sobre la mesa entre todos.',
          explanation: 'Planteamos. No encaja equivocada ni errónea.',
          correct: 'planteó',
          partOfSpeech: 'verbo',
        );
        expect(runWord(validator, word), hasLength(1));
      },
    );

    test('accepts a verb that agrees with the subject pronoun', () {
      final word = exerciseWith(
        sentence: 'Nosotros {{blank}} el tema en la reunión del lunes.',
        hintGeneral: 'Pusimos el tema sobre la mesa entre todos.',
        explanation: 'Planteamos. No encaja equivocada ni errónea.',
        correct: 'planteamos',
        partOfSpeech: 'verbo',
      );
      expect(runWord(validator, word), isEmpty);
    });

    test('stays quiet when there is no determiner before the blank', () {
      final word = exerciseWith(
        sentence: 'El equipo es muy {{blank}} cuando el plazo aprieta.',
        hintGeneral: 'Describe a quien no se rinde.',
        explanation: 'Tenaz. No encaja equivocada ni errónea.',
        correct: 'tenaz',
      );
      expect(runWord(validator, word), isEmpty);
    });
  });

  group('DistractorOverlapValidator', () {
    const validator = DistractorOverlapValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects a distractor that appears in a collocation', () {
      final word = wordFrom({
        'collocations': ['observación perspicaz', 'mirada curiosa'],
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a distractor that is a family member', () {
      final word = wordFrom({
        'family': ['perspicacia', 'sagaz'],
      });
      expect(runWord(validator, word), isNotEmpty);
    });
  });

  group('AnswerLeakageValidator', () {
    const validator = AnswerLeakageValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects the lemma inside a sentence', () {
      final word = wordWithExercise(0, {
        'sentence':
            'Ser perspicaz ayuda, y por eso es tan {{blank}} en el trabajo.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a family member inside a sentence', () {
      final word = wordWithExercise(0, {
        'sentence':
            'Su perspicacia es famosa, así que fue muy {{blank}} otra vez.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a shared stem inside hint_general', () {
      final word = wordWithExercise(0, {
        'hint_general':
            'Piensa en alguien perspicazmente atento a los detalles.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('catches a conjugated verb through its infinitive stem', () {
      final map = validWordMap()
        ..['lemma'] = 'zanjar'
        ..['slug'] = 'zanjar'
        ..['part_of_speech'] = 'verbo'
        ..['syllables'] = ['zan', 'jar']
        ..['stressed_syllable'] = 2
        ..['family'] = <String>[];
      final exercises = (map['exercises']! as List<Object?>)
          .cast<Map<String, Object?>>();
      exercises[0]['sentence'] =
          'Propuso que lo {{blank}} hoy y que zanjemos el tema.';
      expect(runWord(validator, Word.fromMap(map)), isNotEmpty);
    });

    test('allows an unrelated word that shares only four letters', () {
      final word = wordWithExercise(0, {
        'hint_general': 'La persona capta rápido lo que no es evidente.',
      });
      expect(runWord(validator, word), isEmpty);
    });
  });

  group('HintCueValidator', () {
    const validator = HintCueValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects a hint that points at the spelling', () {
      final word = wordWithExercise(0, {
        'hint_general': 'La palabra empieza por pe y no lleva tilde.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a hint that quotes a single letter', () {
      final word = wordWithExercise(0, {
        'hint_general': 'Fíjate en la «z» del final de la palabra.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a spelling cue inside hint_specific', () {
      final word = wordWithOption(0, 0, {
        'hint_specific': 'Se escribe con ese, no con equis.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('allows "se escribe" when it is about how a text is written', () {
      final word = wordWithOption(0, 0, {
        'hint_specific':
            '«Soltar» suena improvisado. ¿Así se escribe un correo?',
      });
      expect(runWord(validator, word), isEmpty);
    });
  });

  group('HintOptionLeakageValidator', () {
    const validator = HintOptionLeakageValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects hint_general naming a distractor of the same exercise', () {
      final word = wordWithExercise(0, {
        'hint_general': 'Se nota que es alguien suspicaz por naturaleza.',
      });
      expect(runWord(validator, word).map((i) => i.code), [
        'hint_option_leakage',
      ]);
    });

    test('is accent- and case-insensitive', () {
      final word = wordWithExercise(0, {
        'hint_general': 'SUSPICÁZ describe justo lo contrario de esto.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test(
      'rejects a common inflection of an option, not only the exact form',
      () {
        final word = exerciseWith(
          sentence: 'Todos notaron el {{blank}} con que trató a los suyos.',
          hintGeneral: 'Detrás hay unos cuidados constantes que le quitaron horas de sueño.',
          explanation: 'Desvelo. No encaja cuidado ni esfuerzo.',
          correct: 'desvelo',
          partOfSpeech: 'sustantivo',
          distractors: ['cuidado', 'esfuerzo'],
        );
        expect(runWord(validator, word).map((i) => i.code), [
          'hint_option_leakage',
        ]);
      },
    );

    test('rejects hint_specific naming a sibling option, not its own', () {
      final word = wordWithOption(0, 0, {
        'hint_specific': 'Piensa si encaja mejor perspicuo aquí.',
      });
      expect(runWord(validator, word).map((i) => i.code), [
        'hint_option_leakage',
      ]);
    });

    test('rejects hint_specific naming the correct answer', () {
      final word = wordWithOption(0, 0, {
        'hint_specific': 'La respuesta correcta es perspicaz, no esta.',
      });
      expect(runWord(validator, word).map((i) => i.code), [
        'hint_option_leakage',
      ]);
    });

    test('allows hint_specific to quote its own option, by design', () {
      final word = wordWithOption(0, 0, {
        'hint_specific': '«Suspicaz» es quien sospecha de los demás, y la frase dice lo contrario.',
      });
      expect(runWord(validator, word), isEmpty);
    });
  });

  group('LengthCapsValidator', () {
    const validator = LengthCapsValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects an explanation over twenty words', () {
      final word = wordFrom({
        'explanation': List.filled(21, 'palabra').join(' '),
      });
      expect(runWord(validator, word), hasLength(1));
    });

    test('rejects a hint_general over twenty-five words', () {
      final word = wordWithExercise(0, {
        'hint_general': List.filled(26, 'pista').join(' '),
      });
      expect(runWord(validator, word), hasLength(1));
    });

    test('rejects a hint_specific over twenty-five words', () {
      final word = wordWithOption(0, 0, {
        'hint_specific': List.filled(26, 'pista').join(' '),
      });
      expect(runWord(validator, word), hasLength(1));
    });
  });

  group('ExerciseExplanationCoverageValidator', () {
    const validator = ExerciseExplanationCoverageValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects an explanation that omits a distractor', () {
      final word = wordWithExercise(0, {
        'explanation':
            'Perspicaz: se da cuenta rápido. «Suspicaz» es quien desconfía.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects an explanation that omits the answer', () {
      final word = wordWithExercise(0, {
        'explanation': '«Suspicaz» es quien desconfía y «perspicuo» es lo que se entiende.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });
  });

  group('ExplanationCircularityValidator', () {
    const validator = ExplanationCircularityValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects an explanation that uses a family member', () {
      final word = wordFrom({
        'explanation': 'Quien tiene perspicacia y capta lo que otros no ven.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects an explanation that uses the word itself', () {
      final word = wordFrom({
        'explanation':
            'Alguien perspicaz nota lo que los demás no ven a tiempo.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });
  });

  group('CommonVocabularyValidator', () {
    const validator = CommonVocabularyValidator();

    test('warns when no frequency list is available', () {
      final issues = runWord(validator, validWord());
      expect(issues, hasLength(1));
      expect(issues.single.severity, Severity.warn);
      expect(issues.single.message, contains('no frequency list'));
    });

    test('accepts an explanation whose words are all common', () {
      final issues = runWord(
        validator,
        validWord(),
        commonLemmas: {
          'dar',
          'cuenta',
          'rapido',
          'obvio',
          'captar',
          'detalle',
          'ver',
        },
      );
      expect(issues, isEmpty);
    });

    test('blocks a rare word once the list exists', () {
      final word = wordFrom({
        'explanation':
            'Quien capta lo que otros no ven con inconcusa celeridad.',
      });
      final issues = runWord(
        validator,
        word,
        commonLemmas: {'captar', 'ver'},
      );
      expect(issues, isNotEmpty);
      expect(issues.first.severity, Severity.blocking);
      expect(issues.map((i) => i.message).join(), contains('inconcusa'));
    });
  });
}
