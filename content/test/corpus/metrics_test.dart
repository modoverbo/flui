import 'package:content/src/corpus/metrics.dart';
import 'package:test/test.dart';

void main() {
  group('zipf', () {
    test('is log10 of the frequency per billion tokens', () {
      expect(zipf(frequency: 1000, totalTokens: 1000000), closeTo(6, 1e-9));
      expect(zipf(frequency: 1, totalTokens: 1000000000), closeTo(0, 1e-9));
    });

    test('is zero for an unseen lemma', () {
      expect(zipf(frequency: 0, totalTokens: 1000), 0);
    });
  });

  group('griesDp', () {
    test('is 0 when a lemma is spread exactly like the corpus', () {
      expect(
        griesDp(observed: [50, 50], partSizes: [1000, 1000]),
        closeTo(0, 1e-9),
      );
    });

    test('is near 1 when a lemma sits in one part only', () {
      expect(
        griesDp(observed: [100, 0], partSizes: [1000, 1000]),
        closeTo(0.5, 1e-9),
      );
      expect(
        griesDp(observed: [100, 0, 0, 0], partSizes: [1000, 1000, 1000, 1000]),
        closeTo(0.75, 1e-9),
      );
    });

    test('accounts for uneven part sizes', () {
      expect(
        griesDp(observed: [90, 10], partSizes: [9000, 1000]),
        closeTo(0, 1e-9),
      );
    });

    test('is 0 for a lemma that never occurs', () {
      expect(griesDp(observed: [0, 0], partSizes: [10, 10]), 0);
    });
  });

  group('guessPartOfSpeech', () {
    test('reads verb infinitives', () {
      expect(guessPartOfSpeech('plantear'), 'verbo');
      expect(guessPartOfSpeech('prever'), 'verbo');
      expect(guessPartOfSpeech('discernir'), 'verbo');
    });

    test('reads -mente adverbs', () {
      expect(guessPartOfSpeech('perspicazmente'), 'adverbio');
    });

    test('reads adjective endings', () {
      expect(guessPartOfSpeech('perspicaz'), 'adjetivo');
      expect(guessPartOfSpeech('pertinente'), 'adjetivo');
      expect(guessPartOfSpeech('minucioso'), 'adjetivo');
    });

    test('knows the closed connector list', () {
      expect(guessPartOfSpeech('asimismo'), 'conector');
    });

    test('falls back to noun', () {
      expect(guessPartOfSpeech('matiz'), 'sustantivo');
    });
  });

  group('looksInflected', () {
    test('rejects conjugated forms that are not lemmas', () {
      for (final form in [
        'organizamos',
        'caminamos',
        'tratemos',
        'plantearon',
        'matizaban',
        'sopesando',
        'concretaría',
        'zanjaste',
        'pensarían',
        'dijeron',
        'dedicarme',
        'llamarnos',
        'recordé',
        'capacitadas',
        'leído',
        'posters',
        'bellísima',
        'imagínese',
        'infórmate',
      ]) {
        expect(looksInflected(form), isTrue, reason: form);
      }
    });

    test('accepts infinitives, nouns and adjectives', () {
      for (final lemma in [
        'matizar',
        'perspicaz',
        'pertinente',
        'matiz',
        'contundente',
        'asimismo',
        'discernir',
        'prever',
      ]) {
        expect(looksInflected(lemma), isFalse, reason: lemma);
      }
    });
  });

  group('looksForeign', () {
    test('rejects tokens Spanish orthography does not produce', () {
      for (final token in ['flickr', 'scanner', 'intranet', 'wifi', 'backup']) {
        expect(looksForeign(token), isTrue, reason: token);
      }
    });

    test('accepts ordinary Spanish words', () {
      for (final token in [
        'matizar',
        'perspicaz',
        'carácter',
        'reloj',
        'crisis',
        'innato',
        'acción',
      ]) {
        expect(looksForeign(token), isFalse, reason: token);
      }
    });
  });

  group('guessPartOfSpeech exceptions', () {
    test('knows the frequent non-verbs that end like an infinitive', () {
      expect(guessPartOfSpeech('caracter'), 'sustantivo');
      expect(guessPartOfSpeech('lugar'), 'sustantivo');
      expect(guessPartOfSpeech('popular'), 'adjetivo');
      expect(guessPartOfSpeech('mujer'), 'sustantivo');
    });
  });

  group('normalizeSurface', () {
    test('keeps letters and drops everything else', () {
      expect(normalizeSurface('Perspicaz,'), 'perspicaz');
      expect(normalizeSurface('42'), isNull);
      expect(normalizeSurface('«'), isNull);
      expect(normalizeSurface('e-mail'), isNull);
    });

    test('rejects one and two letter tokens', () {
      expect(normalizeSurface('de'), isNull);
      expect(normalizeSurface('sol'), 'sol');
    });
  });

  group('surfaceToLemma', () {
    test('maps a plural onto a singular already seen in the corpus', () {
      final known = {'matiz': 400, 'matices': 120};
      expect(surfaceToLemma('matices', known), 'matiz');
    });

    test('maps a conjugated verb onto an infinitive seen in the corpus', () {
      final known = {'plantear': 900, 'planteó': 210};
      expect(surfaceToLemma('planteó', known), 'plantear');
    });

    test('folds the first and second person plural endings', () {
      expect(surfaceToLemma('organizamos', {'organizar': 900}), 'organizar');
      expect(surfaceToLemma('tratemos', {'tratar': 900}), 'tratar');
      expect(surfaceToLemma('comemos', {'comer': 900}), 'comer');
    });

    test('prefers an attested infinitive even when it is rarer', () {
      expect(surfaceToLemma('opina', {'opina': 900, 'opinar': 40}), 'opinar');
      expect(surfaceToLemma('bastan', {'bastan': 500, 'bastar': 12}), 'bastar');
    });

    test('undoes the qu/c and j/g spelling alternations', () {
      expect(surfaceToLemma('impliquen', {'implicar': 80}), 'implicar');
      expect(surfaceToLemma('dirijan', {'dirigir': 80}), 'dirigir');
    });

    test('still keeps a noun that only looks like a verb form', () {
      expect(surfaceToLemma('casa', {'casa': 900}), 'casa');
    });

    test('keeps a surface with no known base', () {
      expect(surfaceToLemma('zanjar', {'zanjar': 30}), 'zanjar');
    });

    test('never maps onto a rarer form', () {
      final known = {'matiz': 5, 'matices': 900};
      expect(surfaceToLemma('matices', known), 'matices');
    });
  });

  group('pedantryProxy', () {
    test('is 0.5 when formal and informal use match', () {
      expect(
        pedantryProxy(formalPerMillion: 100, informalPerMillion: 100),
        closeTo(0.5, 1e-9),
      );
    });

    test('rises when the lemma lives in formal prose', () {
      expect(
        pedantryProxy(formalPerMillion: 1000, informalPerMillion: 10),
        greaterThan(0.8),
      );
    });

    test('falls when the lemma lives on the open web', () {
      expect(
        pedantryProxy(formalPerMillion: 10, informalPerMillion: 1000),
        lessThan(0.2),
      );
    });

    test('is 0.5 when neither corpus has it', () {
      expect(pedantryProxy(formalPerMillion: 0, informalPerMillion: 0), 0.5);
    });
  });

  group('candidateScore', () {
    test('prefers mid frequency, wide spread, low pedantry', () {
      final good = candidateScore(
        zipf: idealZipf,
        dp: 0.15,
        pedantryProxy: 0.4,
        comodinLeverage: 0.8,
        familySize: 3,
      );
      final tooCommon = candidateScore(
        zipf: 6.6,
        dp: 0.15,
        pedantryProxy: 0.4,
        comodinLeverage: 0.8,
        familySize: 3,
      );
      final tooRare = candidateScore(
        zipf: 2,
        dp: 0.15,
        pedantryProxy: 0.4,
        comodinLeverage: 0.8,
        familySize: 3,
      );
      final regional = candidateScore(
        zipf: idealZipf,
        dp: 0.9,
        pedantryProxy: 0.4,
        comodinLeverage: 0.8,
        familySize: 3,
      );

      expect(good, greaterThan(tooCommon));
      expect(good, greaterThan(tooRare));
      expect(good, greaterThan(regional));
      expect(good, inInclusiveRange(0, 1));
    });
  });

  group('candidateScore against the seed words', () {
    // Measured by `dart run content:corpus` over the 21 Leipzig packages.
    // These eight words are the product's own ground truth: whatever the
    // scoring function is, it has to rank them as good candidates.
    const measured = <String, (double, double, double, double, int)>{
      'plantear': (5.210, 0.123, 0.514, 0.404, 133),
      'concretar': (5.062, 0.119, 0.503, 0.453, 53),
      'pertinente': (4.357, 0.242, 0.400, 0.527, 20),
      'contundente': (4.317, 0.150, 0.614, 0.540, 43),
      'matizar': (3.698, 0.211, 0.582, 0.908, 13),
      'zanjar': (3.635, 0.227, 0.714, 0.929, 6),
      'sopesar': (3.314, 0.358, 0.522, 1.000, 6),
      'perspicaz': (2.869, 0.428, 0.631, 1.000, 17),
    };

    test('every seed word scores as a strong candidate', () {
      for (final entry in measured.entries) {
        final (zipf, dp, pedantry, leverage, family) = entry.value;
        expect(
          candidateScore(
            zipf: zipf,
            dp: dp,
            pedantryProxy: pedantry,
            comodinLeverage: leverage,
            familySize: family,
          ),
          greaterThan(0.85),
          reason: entry.key,
        );
      }
    });

    test('a word that is far too common still scores lower', () {
      expect(
        candidateScore(
          zipf: 6.8,
          dp: 0.1,
          pedantryProxy: 0.5,
          comodinLeverage: 0.5,
          familySize: 50,
        ),
        lessThan(0.85),
      );
    });

    test('a country-bound word still scores lower', () {
      expect(
        candidateScore(
          zipf: 4.3,
          dp: 0.85,
          pedantryProxy: 0.5,
          comodinLeverage: 0.9,
          familySize: 10,
        ),
        lessThan(0.85),
      );
    });

    test('a word that only lives in formal prose still scores lower', () {
      expect(
        candidateScore(
          zipf: 4.3,
          dp: 0.15,
          pedantryProxy: 0.99,
          comodinLeverage: 0.3,
          familySize: 2,
        ),
        lessThan(0.85),
      );
    });
  });

  group('editDistance', () {
    test('counts substitutions, insertions and deletions', () {
      expect(editDistance('perspicaz', 'suspicaz'), 3);
      expect(editDistance('perspicaz', 'perspicuo'), 2);
      expect(editDistance('actitud', 'aptitud'), 1);
      expect(editDistance('igual', 'igual'), 0);
    });
  });
}
