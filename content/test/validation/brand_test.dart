import 'package:content/src/validation/brand.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

void main() {
  group('BannedWordsValidator', () {
    const validator = BannedWordsValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects school vocabulary', () {
      for (final banned in <String>[
        'lección',
        'examen',
        'alumno',
        'profesor',
        'tarea',
        'calificación',
        'gramática',
        'memorización',
        'evaluación',
        'incorrecto',
      ]) {
        final word = wordFrom({
          'usage_tip': 'Esta palabra aparece en la $banned de hoy.',
        });
        expect(runWord(validator, word), isNotEmpty, reason: banned);
      }
    });

    test('rejects the SinMuletillas trademark', () {
      final word = wordFrom({'usage_tip': 'Inspirado en #SinMuletillas.'});
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects "error" used as a verdict', () {
      final word = wordWithExercise(0, {
        'explanation':
            'Eso es un error: perspicaz, suspicaz y perspicuo no son lo mismo.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('allows "error" as an ordinary noun in a scene', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test(
      'allows a negated "no es un error", which reassures instead of judging',
      () {
        final word = wordWithExercise(0, {
          'explanation':
              'Perspicaz: no es un error decirlo así. «Suspicaz» desconfía y '
              '«perspicuo» se entiende sin esfuerzo.',
        });
        expect(runWord(validator, word), isEmpty);
      },
    );
  });

  group('SecondPersonValidator', () {
    const validator = SecondPersonValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects usted in an instructional field', () {
      final word = wordFrom({
        'usage_tip': 'Puede usted emplearla cuando quiera elogiar a alguien.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects vosotros forms anywhere, including a reading body', () {
      final word = wordWithReading(0, {
        'body': 'Vosotros ya sabéis cómo terminó la reunión de aquel jueves.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('allows usted inside a reading, where characters may use it', () {
      final word = wordWithReading(0, {
        'body':
            'El director le dijo: «Muy perspicaz, ¿lo comentó usted antes?».',
      });
      expect(runWord(validator, word), isEmpty);
    });
  });

  group('RegionalBlocklistValidator', () {
    const validator = RegionalBlocklistValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects regional vocabulary and tags the country', () {
      final word = wordFrom({
        'usage_tip': 'Sirve para platicar con calma sobre lo que notaste.',
      });
      final issues = runWord(validator, word);
      expect(issues, isNotEmpty);
      expect(issues.first.message, contains('mx'));
    });

    test('rejects voseo forms', () {
      final word = wordFrom({
        'usage_tip':
            'Si vos querés sonar preciso, esta palabra te sirve mucho.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects peninsular slang', () {
      for (final term in <String>['guay', 'curro']) {
        final word = wordFrom({
          'usage_tip': 'Suena $term en cualquier charla.',
        });
        expect(runWord(validator, word), isNotEmpty, reason: term);
      }
    });

    test('flags an ordenador / computadora split inside the library', () {
      final withOrdenador = wordFrom({
        'usage_tip':
            'Úsala cuando alguien nota un fallo del ordenador a tiempo.',
      });
      final withComputadora = wordFrom({
        'slug': 'pertinente',
        'lemma': 'pertinente',
        'usage_tip':
            'Úsala cuando alguien nota un fallo de la computadora a tiempo.',
      });
      final context = contextOf([withOrdenador, withComputadora]);
      final issues = validator.validateWord(withOrdenador, context);
      expect(
        issues.map((i) => i.message).join(),
        contains('inconsistent'),
      );
    });
  });

  group('SensitiveTopicValidator', () {
    const validator = SensitiveTopicValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects each screened topic', () {
      final samples = <String, String>{
        'politics': 'La frase sirve para hablar de las elecciones del domingo.',
        'religion': 'La frase sirve para comentar la misa del domingo pasado.',
        'immigration':
            'La frase sirve para hablar de un indocumentado en la ciudad.',
        'health':
            'La frase sirve para contar que su padre murió el invierno pasado.',
        'sex': 'La frase sirve para hablar de una relación sexual reciente.',
        'violence': 'La frase describe a alguien que quiso matar a su vecino.',
        'brands':
            'La frase compara el servicio de Netflix con el de la tienda.',
        'money_shaming':
            'La frase sirve si alguien dice que ganas poco y te calla.',
        'stereotype':
            'La frase recuerda que los mexicanos son siempre así de amables.',
      };
      for (final entry in samples.entries) {
        final word = wordFrom({'usage_tip': entry.value});
        expect(runWord(validator, word), isNotEmpty, reason: entry.key);
      }
    });
  });

  group('TypographyValidator', () {
    const validator = TypographyValidator();

    test('accepts the canonical word', () {
      expect(runWord(validator, validWord()), isEmpty);
    });

    test('rejects straight double quotes', () {
      final word = wordFrom({
        'usage_tip': 'Se dice "muy perspicaz" y suena bien.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a question mark without its opening sign', () {
      final word = wordFrom({
        'usage_tip': 'Te sirve cuando alguien pregunta qué notaste?',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects an exclamation without its opening sign', () {
      final word = wordFrom({'usage_tip': 'Suena muy natural como elogio!'});
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a double space', () {
      final word = wordFrom({
        'usage_tip': 'Suena natural  como elogio a otra persona.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects unbalanced angle quotes', () {
      final word = wordFrom({
        'usage_tip': 'Se dice «muy perspicaz y suena bien.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('allows the Spanish space before a percent sign', () {
      final word = wordFrom({
        'usage_tip':
            'En la reunión dijo que las ventas cayeron un 20 % este mes.',
      });
      expect(runWord(validator, word), isEmpty);
    });

    test('still catches a space before a period when a percent is present', () {
      final word = wordFrom({
        'usage_tip': 'Las ventas cayeron un 20 % este mes . Nadie lo esperaba.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });

    test('rejects a space before a comma', () {
      final word = wordFrom({
        'usage_tip': 'Suena natural , sobre todo como elogio.',
      });
      expect(runWord(validator, word), isNotEmpty);
    });
  });
}
