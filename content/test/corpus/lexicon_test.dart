import 'package:content/src/corpus/lexicon.dart';
import 'package:test/test.dart';

void main() {
  const tsv = '''
?lemma\t?cat
"matizar"@es\t<http://www.wikidata.org/entity/Q24905>
"matiz"@es\t<http://www.wikidata.org/entity/Q1084>
"perspicaz"@es\t<http://www.wikidata.org/entity/Q34698>
"asimismo"@es\t<http://www.wikidata.org/entity/Q380057>
"Solución"@es\t<http://www.wikidata.org/entity/Q1084>
"de balde"@es\t<http://www.wikidata.org/entity/Q187931>
"platicar"@es-mx\t<http://www.wikidata.org/entity/Q24905>
"sancochar"@es-419\t<http://www.wikidata.org/entity/Q24905>
''';

  group('parseWikidataLexemes', () {
    final lexicon = parseWikidataLexemes(tsv);

    test('reads every lemma with its category', () {
      expect(lexicon.contains('matizar'), isTrue);
      expect(lexicon.categoriesOf('matizar'), contains(LexicalCategory.verb));
      expect(lexicon.categoriesOf('matiz'), contains(LexicalCategory.noun));
      expect(
        lexicon.categoriesOf('perspicaz'),
        contains(LexicalCategory.adjective),
      );
      expect(
        lexicon.categoriesOf('asimismo'),
        contains(LexicalCategory.adverb),
      );
    });

    test('is accent and case insensitive', () {
      expect(lexicon.contains('SOLUCIÓN'), isTrue);
      expect(lexicon.contains('solucion'), isTrue);
    });

    test('keeps an unmapped category as other', () {
      expect(lexicon.categoriesOf('de balde'), contains(LexicalCategory.other));
    });

    test('strips a regional language tag, not only @es', () {
      // Wikidata carries regional lemma variants: "platicar"@es-mx.
      expect(lexicon.contains('platicar'), isTrue);
      expect(lexicon.categoriesOf('platicar'), contains(LexicalCategory.verb));
      expect(lexicon.contains('sancochar'), isTrue);
      expect(lexicon.contains('"platicar"@es-mx'), isFalse);
    });

    test('does not invent entries', () {
      expect(lexicon.contains('desir'), isFalse);
      expect(lexicon.contains('servier'), isFalse);
      expect(lexicon.categoriesOf('desir'), isEmpty);
    });

    test('reports its size', () {
      expect(lexicon.length, 8);
      expect(lexicon.isEmpty, isFalse);
    });
  });

  group('partOfSpeechFor', () {
    final lexicon = parseWikidataLexemes(tsv);

    test('prefers the dictionary category over morphology', () {
      // "matiz" ends like nothing in particular; morphology guesses noun too,
      // but "perspicaz" would be a guess where the dictionary is a fact.
      expect(lexicon.partOfSpeechFor('perspicaz'), 'adjetivo');
      expect(lexicon.partOfSpeechFor('matizar'), 'verbo');
      expect(lexicon.partOfSpeechFor('asimismo'), 'adverbio');
      expect(lexicon.partOfSpeechFor('matiz'), 'sustantivo');
    });

    test('returns null for a lemma it does not know', () {
      expect(lexicon.partOfSpeechFor('desir'), isNull);
    });
  });

  group('toTsv', () {
    test('round trips through the shipped format', () {
      final original = parseWikidataLexemes(tsv);
      final again = parseShippedLexicon(original.toTsv());

      expect(again.length, original.length);
      expect(again.categoriesOf('matizar'), original.categoriesOf('matizar'));
    });

    test('writes a licence header', () {
      expect(parseWikidataLexemes(tsv).toTsv(), startsWith('# '));
    });
  });

  group('empty lexicon', () {
    test('is inert so the pool can fall back to morphology', () {
      const empty = SpanishLexicon({});
      expect(empty.isEmpty, isTrue);
      expect(empty.contains('matizar'), isFalse);
    });
  });
}
