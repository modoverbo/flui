import 'package:flui/features/exercises/domain/text_matching.dart';
import 'package:flui/features/exercises/domain/word_forms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeText', () {
    final cases = <(String, String)>[
      ('  Perspicaz ', 'perspicaz'),
      ('PLANTEÓ', 'planteo'),
      ('matización', 'matizacion'),
      ('Pingüino', 'pinguino'),
      ('Año', 'ano'),
      ('ÁÉÍÓÚ', 'aeiou'),
      ('dos   palabras', 'dos palabras'),
    ];
    for (final (input, expected) in cases) {
      test('"$input" -> "$expected"', () {
        expect(normalizeText(input), expected);
      });
    }
  });

  group('levenshtein', () {
    final cases = <(String, String, int)>[
      ('perspicaz', 'perspicaz', 0),
      ('perspicaz', 'perspikaz', 1),
      ('perspicaz', 'perspicas', 1),
      ('zanjar', 'zanjr', 1),
      ('zanjar', 'zanjara', 1),
      ('zanjar', 'sanjr', 2),
      ('', 'abc', 3),
    ];
    for (final (a, b, distance) in cases) {
      test('$a / $b = $distance', () => expect(levenshtein(a, b), distance));
    }
  });

  group('wordTokens', () {
    test('splits on spaces and punctuation, normalized', () {
      expect(wordTokens('¡Qué pregunta tan perspicaz, Carla!'), [
        'que',
        'pregunta',
        'tan',
        'perspicaz',
        'carla',
      ]);
    });
  });

  group('WordForms', () {
    const perspicaz = WordForms(
      lemma: 'perspicaz',
      isVerb: false,
      extraForms: ['perspicacia', 'perspicazmente'],
    );
    const plantear = WordForms(
      lemma: 'plantear',
      isVerb: true,
      extraForms: ['planteamiento', 'planteó', 'plantearlo'],
    );

    test('stems verbs by removing the infinitive ending', () {
      expect(plantear.stem, 'plante');
      expect(const WordForms(lemma: 'zanjar', isVerb: true).stem, 'zanj');
    });

    test('stems adjectives by removing a final vowel or z', () {
      expect(perspicaz.stem, 'perspica');
      expect(
        const WordForms(lemma: 'contundente', isVerb: false).stem,
        'contundent',
      );
    });

    final matches = <(WordForms, String, bool)>[
      (perspicaz, 'perspicaz', true),
      (perspicaz, 'Perspicaces', true),
      (perspicaz, 'perspicacia', true),
      (perspicaz, 'perspica', false),
      (perspicaz, 'suspicaz', false),
      (plantear, 'planteé', true),
      (plantear, 'PLANTEARLO', true),
      (plantear, 'planteamos', true),
      (plantear, 'plantar', false),
    ];
    for (final (forms, token, expected) in matches) {
      test('${forms.lemma} matches "$token": $expected', () {
        expect(forms.matchesToken(token), expected);
      });
    }

    test('a multi-word lemma is found as a phrase', () {
      const esDecir = WordForms(lemma: 'es decir', isVerb: false);

      expect(esDecir.appearsIn('Lo dije, es decir, lo pensé.'), isTrue);
      expect(esDecir.appearsIn('Lo dije y lo pensé.'), isFalse);
    });

    test('finds the first form used in a sentence', () {
      expect(plantear.findIn('Mañana voy a plantear la posibilidad.'), (
        start: 13,
        end: 21,
      ));
      expect(perspicaz.findIn('Qué observación tan perspicaz: nadie.'), (
        start: 20,
        end: 29,
      ));
      expect(perspicaz.findIn('Sin la palabra.'), isNull);
    });
  });
}
