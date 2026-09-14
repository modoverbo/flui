import 'package:content/src/corpus/candidate_pool.dart';
import 'package:content/src/corpus/cooccurrence.dart';
import 'package:content/src/corpus/domain_seeds.dart';
import 'package:content/src/corpus/leipzig.dart';
import 'package:content/src/corpus/lexicon.dart';
import 'package:test/test.dart';

const _ar = LeipzigPackage('spa-ar', CorpusRole.country, country: 'ar');
const _mx = LeipzigPackage('spa-mx', CorpusRole.country, country: 'mx');
const _news = LeipzigPackage('spa_news', CorpusRole.formal);
const _web = LeipzigPackage('spa_web', CorpusRole.informal);

String _alpha(int n) {
  var text = '';
  var rest = n;
  do {
    text = String.fromCharCode(97 + rest % 26) + text;
    rest ~/= 26;
  } while (rest > 0);
  return text;
}

List<PackageCounts> corpus({
  Map<String, int> ar = const {},
  Map<String, int> mx = const {},
  Map<String, int> news = const {},
  Map<String, int> web = const {},
}) {
  final filler = {for (var i = 0; i < 2000; i++) 'rell${_alpha(i)}': 5000};
  return [
    PackageCounts(_ar, {...filler, ...ar}),
    PackageCounts(_mx, {...filler, ...mx}),
    PackageCounts(_news, {...filler, ...news}),
    PackageCounts(_web, {...filler, ...web}),
  ];
}

/// A lexicon containing exactly the given lemmas, with the given categories.
SpanishLexicon lexiconOf(Map<String, LexicalCategory> entries) =>
    SpanishLexicon({
      for (final entry in entries.entries) entry.key: {entry.value},
    });

/// Builds an evidence index straight from word pairs, skipping the file layer.
EvidenceIndex evidenceOf(
  Set<String> interesting,
  List<(String, String, double)> pairs, {
  Set<String> comodinArguments = const {},
  Map<String, Set<String>> extraGroups = const {},
}) {
  final builder = EvidenceBuilder(
    interesting: interesting,
    groups: {
      comodinGroup: comodinArguments,
      abstractGroup: abstractMarkers,
      physicalGroup: physicalMarkers,
      for (final entry in themeMarkers.entries)
        themeGroup(entry.key): entry.value,
      ...extraGroups,
    },
  );
  for (final (a, b, sig) in pairs) {
    builder.add(a, b, sig);
  }
  return builder.build();
}

void main() {
  group('dictionary gate', () {
    test('drops a form the dictionary does not attest', () {
      final pool = buildCandidatePool(
        corpus(
          ar: {'matizar': 300, 'servier': 300, 'desir': 300},
          mx: {'matizar': 280, 'servier': 280, 'desir': 280},
        ),
        lexicon: lexiconOf({'matizar': LexicalCategory.verb}),
      );

      expect(pool.map((r) => r.lemma), contains('matizar'));
      expect(pool.map((r) => r.lemma), isNot(contains('servier')));
      expect(pool.map((r) => r.lemma), isNot(contains('desir')));
    });

    test('drops a dictionary verb that is not an infinitive', () {
      final pool = buildCandidatePool(
        corpus(ar: {'matiza': 300}, mx: {'matiza': 280}),
        lexicon: lexiconOf({'matiza': LexicalCategory.verb}),
      );

      expect(pool, isEmpty);
    });

    test(
      'takes the part of speech from the dictionary, not from morphology',
      () {
        final pool = buildCandidatePool(
          corpus(ar: {'caracter': 300}, mx: {'caracter': 280}),
          lexicon: lexiconOf({'caracter': LexicalCategory.noun}),
        );

        expect(pool.single.pos, 'sustantivo');
      },
    );

    test('keeps everything when no dictionary is available', () {
      final pool = buildCandidatePool(
        corpus(ar: {'matizar': 300}, mx: {'matizar': 280}),
        lexicon: const SpanishLexicon({}),
      );

      final row = pool.firstWhere((r) => r.lemma == 'matizar');
      expect(row.flags, contains('dictionary-unverified'));
    });
  });

  group('domain gate', () {
    const lexicon = SpanishLexicon({
      'matizar': {LexicalCategory.verb},
      'frotar': {LexicalCategory.verb},
    });

    List<CandidateRow> poolWith(List<(String, String, double)> pairs) =>
        buildCandidatePool(
          corpus(
            ar: {'matizar': 300, 'frotar': 300},
            mx: {'matizar': 280, 'frotar': 280},
          ),
          lexicon: lexicon,
          evidence: evidenceOf({'matizar', 'frotar'}, pairs),
          policy: PoolPolicy.permissive,
        );

    test('drops a verb whose company is physical', () {
      final pool = poolWith([
        ('matizar', 'propuesta', 300),
        ('matizar', 'argumento', 200),
        ('frotar', 'piel', 300),
        ('frotar', 'sarten', 200),
      ]);

      expect(pool.map((r) => r.lemma), ['matizar']);
    });

    test('keeps a verb whose company is abstract', () {
      final pool = poolWith([
        ('matizar', 'opinion', 400),
        ('frotar', 'idea', 400),
      ]);

      expect(pool.map((r) => r.lemma), containsAll(['matizar', 'frotar']));
    });

    test('drops a candidate with no co-occurrence evidence at all', () {
      final pool = poolWith([('matizar', 'propuesta', 300)]);

      expect(pool.map((r) => r.lemma), isNot(contains('frotar')));
    });

    test('flags the gate as unverified when there is no evidence index', () {
      final pool = buildCandidatePool(
        corpus(ar: {'frotar': 300}, mx: {'frotar': 280}),
        lexicon: lexicon,
      );

      expect(pool.single.flags, contains('domain-unverified'));
    });
  });

  group('comodín gate', () {
    test('drops the candidates with the weakest comodín evidence', () {
      final lemmas = [for (var i = 0; i < 30; i++) 'tem${_alpha(i)}ar'];
      final sharers = lemmas.take(10).toSet();
      final pool = buildCandidatePool(
        corpus(
          ar: {for (final l in lemmas) l: 300},
          mx: {for (final l in lemmas) l: 280},
        ),
        lexicon: SpanishLexicon({
          for (final l in lemmas) l: const {LexicalCategory.verb},
        }),
        evidence: evidenceOf(
          lemmas.toSet(),
          [
            for (final l in lemmas)
              if (sharers.contains(l)) ...[
                (l, 'tema', 400),
                (l, 'idea', 100),
              ] else
                (l, 'idea', 500),
          ],
          comodinArguments: {'tema'},
        ),
        policy: const PoolPolicy(abstractMinimumLift: 0),
      );

      // Only the ten that share the comodín argument survive the gate.
      expect(pool.length, lessThanOrEqualTo(10));
      for (final row in pool) {
        expect(sharers.map((l) => l).contains(row.lemma), isTrue);
      }
    });

    test('spreads leverage across the survivors instead of saturating', () {
      final lemmas = [for (var i = 0; i < 20; i++) 'tem${_alpha(i)}ar'];
      final pool = buildCandidatePool(
        corpus(
          ar: {for (final l in lemmas) l: 300},
          mx: {for (final l in lemmas) l: 280},
        ),
        lexicon: SpanishLexicon({
          for (final l in lemmas) l: const {LexicalCategory.verb},
        }),
        evidence: evidenceOf(
          lemmas.toSet(),
          [
            for (var i = 0; i < lemmas.length; i++) ...[
              (lemmas[i], 'tema', 50.0 * (i + 1)),
              (lemmas[i], 'idea', 500),
            ],
          ],
          comodinArguments: {'tema'},
        ),
        policy: const PoolPolicy(comodinKeepShare: 1, abstractMinimumLift: 0),
      );

      final leverages = pool.map((r) => r.comodinLeverage).toSet();
      expect(leverages.length, greaterThan(1));
      expect(leverages.every((l) => l >= 0 && l <= 1), isTrue);
    });
  });

  group('comodin leverage', () {
    const lexicon = SpanishLexicon({
      'plantear': {LexicalCategory.verb},
      'sintonizar': {LexicalCategory.verb},
    });

    test('is high only when the candidate shares the comodin arguments', () {
      final pool = buildCandidatePool(
        corpus(
          ar: {'plantear': 300, 'sintonizar': 300},
          mx: {'plantear': 280, 'sintonizar': 280},
        ),
        lexicon: lexicon,
        evidence: evidenceOf(
          {'plantear', 'sintonizar'},
          [
            ('plantear', 'tema', 400),
            ('plantear', 'propuesta', 300),
            ('sintonizar', 'emisora', 400),
            ('sintonizar', 'idea', 100),
          ],
          comodinArguments: {'tema', 'propuesta', 'cosa'},
        ),
        policy: PoolPolicy.permissive,
      );

      // "sintonizar" keeps company with emisora and frecuencia, never with
      // what the comodín verbs take, so it has no leverage at all and the
      // gate drops it instead of ranking it near the top.
      expect(pool.map((r) => r.lemma), ['plantear']);
      expect(pool.single.comodinLeverage, 1);
    });
  });

  group('theme assignment', () {
    const lexicon = SpanishLexicon({
      'plantear': {LexicalCategory.verb},
      'elogiar': {LexicalCategory.verb},
      'flotar': {LexicalCategory.verb},
    });

    test('assigns a theme only on evidence', () {
      final pool = buildCandidatePool(
        corpus(
          ar: {'plantear': 300, 'elogiar': 300},
          mx: {'plantear': 280, 'elogiar': 280},
        ),
        lexicon: lexicon,
        evidence: evidenceOf(
          {'plantear', 'elogiar'},
          [
            ('plantear', 'reunion', 400),
            ('plantear', 'acta', 200),
            ('plantear', 'idea', 100),
            ('elogiar', 'merito', 400),
            ('elogiar', 'logro', 200),
            ('elogiar', 'idea', 100),
          ],
        ),
        policy: const PoolPolicy(
          comodinKeepShare: 1,
          abstractMinimumLift: 0,
          themeMinimumLift: 1.5,
          themeMinimumShare: 0,
        ),
      );

      expect(
        pool.firstWhere((r) => r.lemma == 'plantear').suggestedThemes,
        contains('reuniones'),
      );
      expect(
        pool.firstWhere((r) => r.lemma == 'elogiar').suggestedThemes,
        contains('elogio-reconocimiento'),
      );
    });

    test('leaves the theme empty when nothing supports one', () {
      final pool = buildCandidatePool(
        corpus(ar: {'plantear': 300}, mx: {'plantear': 280}),
        lexicon: lexicon,
        evidence: evidenceOf({'plantear'}, [('plantear', 'idea', 400)]),
        policy: PoolPolicy.permissive,
      );

      expect(pool.single.suggestedThemes, isEmpty);
    });

    test('never lets one theme own more than the share cap', () {
      // Alphabetic infinitives: a digit would be stripped by normalizeSurface
      // and collapse all forty onto one lemma. Eight of the forty keep the
      // theme's company, so their lift clears the bar while the rest sit at
      // the baseline; the cap then trims eight down to six.
      final lemmas = [for (var i = 0; i < 40; i++) 'tem${_alpha(i)}ar'];
      final carriers = lemmas.take(8).toSet();
      final pool = buildCandidatePool(
        corpus(
          ar: {for (final l in lemmas) l: 300},
          mx: {for (final l in lemmas) l: 280},
        ),
        lexicon: SpanishLexicon({
          for (final l in lemmas) l: const {LexicalCategory.verb},
        }),
        evidence: evidenceOf(lemmas.toSet(), [
          for (final l in lemmas)
            if (carriers.contains(l)) ...[
              (l, 'reunion', 400),
              (l, 'idea', 50),
            ] else
              (l, 'idea', 450),
        ]),
        policy: const PoolPolicy(
          comodinKeepShare: 1,
          abstractMinimumLift: 0,
          themeMinimumShare: 0,
        ),
      );

      final allowed = (pool.length * 0.15).ceil();
      final withTheme = pool
          .where((r) => r.suggestedThemes.contains('reuniones'))
          .length;
      // A few generated forms hit the foreign-spelling filter (k, w, mm),
      // which is the filter doing its job; the cap is what this test checks.
      expect(pool.length, greaterThan(30));
      expect(withTheme, lessThanOrEqualTo(allowed));
      expect(withTheme, greaterThan(0));
    });
  });
}
