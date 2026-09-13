import 'package:content/src/text/spanish_morphology.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:test/test.dart';

void main() {
  group('stripDiacritics', () {
    test('removes acute accents and diaeresis but keeps enye', () {
      expect(stripDiacritics('perspicáz'), 'perspicaz');
      expect(stripDiacritics('LingÜística'), 'LingUistica');
      expect(stripDiacritics('mañana'), 'mañana');
    });

    test('is a no-op for plain ascii', () {
      expect(stripDiacritics('plantear'), 'plantear');
    });
  });

  group('foldForComparison', () {
    test('lowercases and removes diacritics', () {
      expect(foldForComparison('Perspicáz'), 'perspicaz');
    });

    test('keeps enye distinct from n', () {
      expect(foldForComparison('AÑO'), 'año');
    });
  });

  group('slugify', () {
    test('turns a lemma into its slug', () {
      expect(slugify('perspicaz'), 'perspicaz');
      expect(slugify('a propósito'), 'a-proposito');
      expect(slugify('Dicho de otro modo'), 'dicho-de-otro-modo');
    });

    test('collapses punctuation and repeated separators', () {
      expect(slugify('  es decir,  '), 'es-decir');
      expect(slugify('mañana'), 'manana');
    });
  });

  group('tokenizeWords', () {
    test('splits on non-letters and keeps accented letters', () {
      expect(tokenizeWords('Qué observación tan perspicaz.'), [
        'Qué',
        'observación',
        'tan',
        'perspicaz',
      ]);
    });

    test('does not split the blank token into letters only', () {
      expect(tokenizeWords('es tan {{blank}} que'), [
        'es',
        'tan',
        'blank',
        'que',
      ]);
    });

    test('ignores digits and percent signs', () {
      expect(tokenizeWords('un 40 % más'), ['un', 'más']);
    });
  });

  group('countWords', () {
    test('counts word tokens', () {
      expect(countWords('Poner sobre la mesa un tema.'), 6);
      expect(countWords('   '), 0);
    });
  });

  group('shingles', () {
    test('builds word n-grams', () {
      expect(shingles('a b c d', 2), {'a b', 'b c', 'c d'});
    });

    test('returns the whole text when it is shorter than n', () {
      expect(shingles('a b', 3), {'a b'});
    });

    test('folds case and accents so near-duplicates collide', () {
      expect(shingles('Él vino', 2), shingles('el VINO', 2));
    });
  });

  group('jaccard', () {
    test('is 1 for identical sets and 0 for disjoint ones', () {
      expect(jaccard({'a', 'b'}, {'a', 'b'}), 1);
      expect(jaccard({'a'}, {'b'}), 0);
    });

    test('is the intersection over the union', () {
      expect(jaccard({'a', 'b', 'c'}, {'b', 'c', 'd'}), closeTo(0.5, 1e-9));
    });

    test('is 0 when either side is empty', () {
      expect(jaccard(<String>{}, {'a'}), 0);
    });
  });

  group('openingNgram', () {
    test('takes the first n folded tokens', () {
      expect(openingNgram('Antes de firmar el contrato', 3), 'antes de firmar');
    });

    test('returns null when the text is too short', () {
      expect(openingNgram('Antes de', 3), isNull);
    });
  });

  group('lemmaCandidates', () {
    test('strips a clitic glued to an infinitive', () {
      expect(lemmaCandidates('hablarlo'), contains('hablar'));
      expect(lemmaCandidates('matizarlo'), contains('matizar'));
    });

    test('knows the frequent irregular preterites', () {
      expect(lemmaCandidates('dijo'), contains('decir'));
      expect(lemmaCandidates('hizo'), contains('hacer'));
      expect(lemmaCandidates('puso'), contains('poner'));
    });

    test('keeps the surface form itself', () {
      expect(lemmaCandidates('matiz'), contains('matiz'));
    });
  });

  group('stem', () {
    test('takes the first n characters of the folded lemma', () {
      expect(stem('perspicaz', 5), 'persp');
      expect(stem('ir', 5), 'ir');
    });
  });
}
