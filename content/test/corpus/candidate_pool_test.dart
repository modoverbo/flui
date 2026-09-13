import 'package:content/src/corpus/candidate_pool.dart';
import 'package:content/src/corpus/leipzig.dart';
import 'package:test/test.dart';

PackageCounts counts(LeipzigPackage package, Map<String, int> words) =>
    PackageCounts(package, words);

const _ar = LeipzigPackage('spa-ar', CorpusRole.country, country: 'ar');
const _mx = LeipzigPackage('spa-mx', CorpusRole.country, country: 'mx');
const _news = LeipzigPackage('spa_news', CorpusRole.formal);
const _web = LeipzigPackage('spa_web', CorpusRole.informal);

/// Alphabetic filler id, so a filler token never carries a digit.
String _alpha(int n) {
  var text = '';
  var rest = n;
  do {
    text = String.fromCharCode(97 + rest % 26) + text;
    rest ~/= 26;
  } while (rest > 0);
  return text;
}

/// A tiny corpus with enough filler that the Zipf window means something:
/// 2000 filler types at 5000 occurrences give 10M tokens per package.
List<PackageCounts> tinyCorpus({
  Map<String, int> ar = const {},
  Map<String, int> mx = const {},
  Map<String, int> news = const {},
  Map<String, int> web = const {},
}) {
  final filler = {for (var i = 0; i < 2000; i++) 'rell${_alpha(i)}': 5000};
  return [
    counts(_ar, {...filler, ...ar}),
    counts(_mx, {...filler, ...mx}),
    counts(_news, {...filler, ...news}),
    counts(_web, {...filler, ...web}),
  ];
}

void main() {
  group('parseWordsFile', () {
    test('reads the Leipzig rank/word/frequency table', () {
      final parsed = parseWordsFile('1\tque\t900\n2\tmatiz\t12\n\nbad line\n');

      expect(parsed, {'que': 900, 'matiz': 12});
    });
  });

  group('buildCandidatePool', () {
    test('drops function words, short words and tokens with digits', () {
      final pool = buildCandidatePool(
        tinyCorpus(
          ar: {'perspicaz': 60, 'de': 900000, 'sol': 400, 'h2o': 300},
          mx: {'perspicaz': 55},
        ),
      );

      final lemmas = pool.map((r) => r.lemma).toSet();
      expect(lemmas, contains('perspicaz'));
      expect(lemmas, isNot(contains('de')));
      expect(lemmas, isNot(contains('sol')));
      expect(lemmas, isNot(contains('h2o')));
    });

    test('flags a lemma that only one country uses', () {
      final pool = buildCandidatePool(
        tinyCorpus(ar: {'laburo': 400}, mx: {'perspicaz': 200, 'trabajo': 200}),
      );
      final laburo = pool.firstWhere((r) => r.lemma == 'laburo');

      expect(laburo.flags, contains('regional-only'));
    });

    test('flags paronyms inside the pool', () {
      final pool = buildCandidatePool(
        tinyCorpus(
          ar: {'actitud': 200, 'aptitud': 180},
          mx: {'actitud': 190, 'aptitud': 170},
        ),
      );
      final actitud = pool.firstWhere((r) => r.lemma == 'actitud');

      expect(
        actitud.flags.where((f) => f.startsWith('paronym-of:')),
        contains('paronym-of:aptitud'),
      );
    });

    test('drops a lemma that no country subcorpus attests', () {
      final pool = buildCandidatePool(
        tinyCorpus(
          ar: {'perspicaz': 200},
          news: {'ficcin': 900},
          web: {'ficcin': 900},
        ),
      );

      expect(pool.map((r) => r.lemma), isNot(contains('ficcin')));
    });

    test('drops conjugated forms that are not lemmas', () {
      final pool = buildCandidatePool(
        tinyCorpus(
          ar: {'organizamos': 300, 'perspicaz': 200},
          mx: {'organizamos': 280, 'perspicaz': 190},
        ),
      );

      expect(pool.map((r) => r.lemma), isNot(contains('organizamos')));
      expect(pool.map((r) => r.lemma), contains('perspicaz'));
    });

    test('merges accent variants and keeps the dominant spelling', () {
      final pool = buildCandidatePool(
        tinyCorpus(
          ar: {'solución': 300, 'solucion': 40},
          mx: {'solución': 280, 'solucion': 30},
        ),
      );
      final lemmas = pool.map((r) => r.lemma).toList();

      expect(lemmas, contains('solución'));
      expect(lemmas, isNot(contains('solucion')));
    });

    test('gives every row a semantic-set id', () {
      final pool = buildCandidatePool(tinyCorpus(ar: {'matizar': 200}));

      expect(
        pool.every((r) => r.flags.any((f) => f.startsWith('semantic-set:'))),
        isTrue,
      );
    });

    test('suggests themes from the stem lexicon', () {
      final pool = buildCandidatePool(
        tinyCorpus(ar: {'matizar': 200}, mx: {'matizar': 180}),
      );
      final row = pool.firstWhere((r) => r.lemma == 'matizar');

      expect(row.suggestedThemes, contains('matices-precision'));
    });

    test('ranks by score and honours the limit', () {
      final mid = <String, int>{
        for (final lemma in [
          'perspicaz',
          'suspicaz',
          'matizar',
          'zanjar',
          'sopesar',
          'plantear',
          'concretar',
          'contundente',
        ])
          lemma: 200,
      };
      final pool = buildCandidatePool(tinyCorpus(ar: mid, mx: mid), limit: 5);

      expect(pool, hasLength(5));
      for (var i = 1; i < pool.length; i++) {
        expect(pool[i - 1].score, greaterThanOrEqualTo(pool[i].score));
      }
    });

    test('computes a pedantry proxy above 0.5 for a news-only lemma', () {
      final pool = buildCandidatePool(
        tinyCorpus(
          ar: {'pertinente': 30},
          mx: {'pertinente': 30},
          news: {'pertinente': 1000},
          web: {'pertinente': 20},
        ),
      );
      final row = pool.firstWhere((r) => r.lemma == 'pertinente');

      expect(row.pedantryProxy, greaterThan(0.5));
    });
  });

  group('topLemmas', () {
    test('returns the most frequent lemmas first', () {
      final top = topLemmas(
        tinyCorpus(ar: {'perspicaz': 10, 'trabajo': 9000}),
        limit: 3,
      );

      expect(top.first, isNot('perspicaz'));
      expect(top, hasLength(3));
    });
  });

  group('fallbackPool', () {
    test('never invents a number', () {
      final rows = fallbackPool(['matizar', 'zanjar']);

      expect(rows, hasLength(2));
      expect(rows.first.metricsPending, isTrue);
      final csv = toCsv(rows);
      expect(
        csv.split('\n')[1],
        'matizar,verbo,,,,,,matices-precision,,editorial-fallback,true',
      );
    });
  });

  group('toCsv', () {
    test('writes the documented header', () {
      expect(toCsv(const []).trim(), candidateCsvHeader.join(','));
    });

    test('quotes a field with a comma', () {
      const row = CandidateRow(
        lemma: 'x,y',
        pos: 'sustantivo',
        zipf: 1,
        dp: 0,
        pedantryProxy: 0,
        familySize: 0,
        comodinLeverage: 0,
        suggestedThemes: [],
        score: 0,
        flags: [],
      );

      expect(toCsv([row]), contains('"x,y"'));
    });
  });
}
