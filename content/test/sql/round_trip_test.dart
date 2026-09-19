import 'dart:io';

import 'package:content/src/model/word.dart';
import 'package:content/src/model/word_yaml.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:content/src/sql/seed_emitter.dart';
import 'package:content/src/sql/seed_importer.dart';
import 'package:content/src/sql/seed_sql_parser.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

final String seedPath = p.normalize(
  p.join(Directory.current.path, '..', 'supabase', 'seed.sql'),
);

/// A catalogue word with a new identity, its family and its confusions.
///
/// Every word carries at least one confusion, the way the validator suite
/// demands, so the emitted fragment is always parseable SQL.
Word catalogued(
  String lemma, {
  List<String> family = const [],
  List<String> confusedWith = const ['una palabra de fuera'],
}) => Word.fromMap(
  validWordMap()
    ..remove('id')
    ..['slug'] = slugify(lemma)
    ..['lemma'] = lemma
    ..['syllables'] = [lemma]
    ..['stressed_syllable'] = 1
    ..['family'] = family
    ..['confusions'] = [
      for (final other in confusedWith)
        {
          'confused_with': other,
          'difference': 'Una diferencia clara entre las dos palabras.',
          'memory_trick': 'Un truco corto para recordarla.',
        },
    ],
);

/// The `word_confusions` rows of an emitted fragment, in emission order.
List<Map<String, Object?>> confusionRows(String sql) =>
    parseSeedRows(sql)['word_confusions'] ?? const [];

void main() {
  final seedSql = File(seedPath).readAsStringSync();

  group('parseSeedRows', () {
    test('reads every seed word with its children', () {
      // Counting rows against a fixed number would just record how big the
      // catalog was on the day the test was written. What the parser owes is
      // that the children add up: three options per exercise, three readings
      // per word, at least one confusion each.
      final rows = parseSeedRows(seedSql);
      final words = rows['words']!;

      expect(words, isNotEmpty);
      expect(rows['readings'], hasLength(words.length * 3));
      expect(
        rows['exercise_options'],
        hasLength(rows['exercises']!.length * 3),
      );
      expect(
        rows['word_confusions']!.length,
        greaterThanOrEqualTo(words.length),
      );
      expect(
        rows['exercises']!.length,
        greaterThanOrEqualTo(words.length * 6),
      );
    });

    test('reads the word_themes select-from-values block', () {
      const sql = '''
insert into public.word_themes (word_id, theme_id, relevance, sort_order)
select w.id, t.id, v.relevance, w.sort_order
from (values
  ('perspicaz', 'reuniones', 2),
  ('perspicaz', 'matices-precision', 1)
) as v (word_slug, theme_slug, relevance)
join public.words w on w.slug = v.word_slug
join public.themes t on t.slug = v.theme_slug
on conflict (word_id, theme_id) do update
  set relevance = excluded.relevance;
''';

      expect(parseSeedRows(sql)['word_themes'], [
        {'word_slug': 'perspicaz', 'theme_slug': 'reuniones', 'relevance': 2},
        {
          'word_slug': 'perspicaz',
          'theme_slug': 'matices-precision',
          'relevance': 1,
        },
      ]);
    });

    test('keeps typed values', () {
      final word = parseSeedRows(seedSql)['words']!.first;

      expect(word['slug'], 'perspicaz');
      expect(word['stressed_syllable'], 3);
      expect(word['published'], isTrue);
      expect(word['syllables'], ['pers', 'pi', 'caz']);
      expect(word['ipa_latam'], '[pers.piˈkas]');
    });
  });

  group('splitSeed', () {
    test('keeps the subscription plans in the preamble', () {
      final parts = splitSeed(seedSql);

      expect(parts.preamble, contains('subscription_plans'));
      expect(parts.preamble, isNot(contains('insert into public.words')));
      expect(parts.words, startsWith('-- ----'));
      expect('${parts.preamble}${parts.words}', seedSql);
    });
  });

  group('importSeedWords', () {
    test('carries the themes the seed tags the word with', () {
      final perspicaz = importSeedWords(
        seedSql,
      ).firstWhere((w) => w['slug'] == 'perspicaz');

      expect(perspicaz['themes'], [
        {'slug': 'elogio-reconocimiento', 'relevance': 3},
        {'slug': 'reuniones', 'relevance': 2},
        {'slug': 'matices-precision', 'relevance': 1},
      ]);
    });

    test('gives a word the seed tags with nothing an empty theme list', () {
      const sql = '''
insert into public.words
  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,
   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,
   semantic_set_id, sort_order, published)
values (
  'w1', 'suelto', 'suelto', 'adjetivo', array['suel', 'to']::text[], 1, null, null, 'x',
  'y', 'neutral', 1, null, null, array[]::text[], '[]'::jsonb, array[]::text[],
  null, 1, true
);
''';

      expect(importSeedWords(sql).single['themes'], isEmpty);
    });
  });

  group('word YAML', () {
    test('an imported word survives a YAML round trip unchanged', () {
      final imported = importSeedWords(seedSql).first;
      final yaml = writeWordYaml(imported);
      final reparsed = loadYamlAsPlain(yaml)! as Map<String, Object?>;

      expect(reparsed, imported);
    });

    test('the canonical fixture survives a YAML round trip unchanged', () {
      final original = validWordMap();
      final reparsed =
          loadYamlAsPlain(writeWordYaml(original))! as Map<String, Object?>;

      expect(reparsed, original);
    });
  });

  group('emitSeed', () {
    test('reproduces supabase/seed.sql byte for byte', () {
      final parts = splitSeed(seedSql);
      final words = [
        for (final map in importSeedWords(seedSql)) Word.fromMap(map),
      ];

      final emitted = emitSeed(
        preamble: parts.preamble,
        words: approvedWordsInOrder(words),
      );

      expect(emitted.length, seedSql.length);
      expect(emitted, seedSql);
    });

    test('round trips through YAML text as well', () {
      final parts = splitSeed(seedSql);
      final words = [
        for (final map in importSeedWords(seedSql))
          Word.fromMap(
            loadYamlAsPlain(writeWordYaml(map))! as Map<String, Object?>,
          ),
      ];

      expect(
        emitSeed(preamble: parts.preamble, words: approvedWordsInOrder(words)),
        seedSql,
      );
    });

    test('gives a word without an id a deterministic one', () {
      final map = validWordMap()..remove('id');
      final sql = emitWords([Word.fromMap(map)]);
      final again = emitWords([Word.fromMap(validWordMap()..remove('id'))]);

      expect(sql, again);
      expect(sql, contains(deterministicWordId('perspicaz')));
    });

    test('emits only approved words', () {
      final draft = Word.fromMap(validWordMap()..['status'] = 'draft');
      final approved = Word.fromMap(validWordMap());

      expect(approvedWordsInOrder([draft, approved]), [approved]);
    });

    test('the sort_order it writes rises with the emitted order', () {
      // `sort_order` is the introduction order of the session planner, so a
      // word emitted later must never carry a lower number than one emitted
      // before it — otherwise the file says one thing and the database
      // another. Words without an authored order come last and continue past
      // the highest authored value instead of restarting at 1.
      Word numbered(String slug, int? order) => Word.fromMap(
        validWordMap()
          ..['slug'] = slug
          ..['lemma'] = slug
          ..['syllables'] = [slug]
          ..['stressed_syllable'] = 1
          ..['sort_order'] = order,
      );
      final words = approvedWordsInOrder([
        numbered('avoid', null),
        numbered('beta', 103),
        numbered('alfa', 8),
      ]);

      expect(words.map((w) => w.slug), ['alfa', 'beta', 'avoid']);
      expect(sortOrdersFor(words), [8, 103, 104]);
    });

    test('numbers an unordered catalog from one', () {
      Word plain(String slug) => Word.fromMap(
        validWordMap()
          ..['slug'] = slug
          ..['lemma'] = slug
          ..['syllables'] = [slug]
          ..['stressed_syllable'] = 1
          ..remove('sort_order'),
      );

      expect(sortOrdersFor([plain('alfa'), plain('beta')]), [1, 2]);
    });

    test('emitted SQL parses back into the same rows', () {
      final word = Word.fromMap(validWordMap());
      final rows = parseSeedRows(emitWords([word]));

      expect(rows['words'], hasLength(1));
      expect(rows['exercises'], hasLength(8));
      expect(rows['exercise_options'], hasLength(24));
      expect(rows['readings'], hasLength(3));
      expect(rows['words']!.first['explanation'], word.explanation);
    });

    test('carries semantic_set_id as a words column', () {
      final withSet = Word.fromMap(
        validWordMap()..['semantic_set_id'] = 'fuerza-de-la-afirmacion',
      );
      final without = Word.fromMap(validWordMap());

      expect(emitWords([withSet]), contains('semantic_set_id'));
      expect(emitWords([withSet]), contains("'fuerza-de-la-afirmacion'"));
      // The column is always present; a word in no set carries null.
      expect(emitWords([without]), contains('semantic_set_id'));
      final row = parseSeedRows(emitWords([without]))['words']!.single;
      expect(row.containsKey('semantic_set_id'), isTrue);
      expect(row['semantic_set_id'], isNull);
    });

    test('emits word_themes links resolved by slug', () {
      final word = Word.fromMap(
        validWordMap()
          ..['themes'] = [
            {'slug': 'reuniones', 'relevance': 3},
            {'slug': 'entrevistas', 'relevance': 1},
          ],
      );
      final sql = emitWords([word]);

      expect(sql, contains('insert into public.word_themes'));
      expect(sql, contains("('perspicaz', 'reuniones', 3)"));
      expect(sql, contains("('perspicaz', 'entrevistas', 1)"));
      // Resolved by slug, so the emitter never duplicates the theme uuids.
      expect(sql, contains('join public.themes t on t.slug = v.theme_slug'));
      expect(sql, isNot(contains('c0000000-')));
    });

    test('emits no word_themes block when no word carries a theme', () {
      final sql = emitWords([Word.fromMap(validWordMap()..['themes'] = [])]);

      expect(sql, isNot(contains('word_themes')));
    });

    test('the word_themes block never confuses the app seed parser', () {
      final word = Word.fromMap(
        validWordMap()
          ..['themes'] = [
            {'slug': 'reuniones', 'relevance': 3},
          ],
      );
      final rows = parseSeedRows(emitWords([word]));

      expect(rows['words'], hasLength(1));
      expect(rows['exercises'], hasLength(8));
      expect(rows['exercise_options'], hasLength(24));
      expect(rows['readings'], hasLength(3));
    });

    test('emits the theme catalogue only when asked', () {
      final word = Word.fromMap(validWordMap());

      expect(emitWords([word]), isNot(contains('insert into public.themes')));
      expect(
        emitWords([word], taxonomy: testTaxonomy),
        contains('insert into public.themes'),
      );
      expect(
        emitWords([word], taxonomy: testTaxonomy),
        contains("'reuniones'"),
      );
    });

    test('escapes apostrophes in literals', () {
      expect(sqlLiteral("l'ami"), "'l''ami'");
      expect(sqlLiteral(null), 'null');
    });

    test(
      'inserts word_confusions only after every words insert, even when a '
      'confusion resolves to a word that sorts later',
      () {
        // `word_confusions.confused_word_id` is a foreign key into
        // `public.words`. `alfa` declares a confusion that resolves to
        // `beta`, which is emitted after it — a per-word emission order
        // would insert alfa's confusion row before beta's word row exists,
        // and `supabase db reset` would fail the FK check while loading
        // supabase/seed.sql.
        final sql = emitWords([
          catalogued('alfa', confusedWith: ['beta']),
          catalogued('beta'),
        ]);

        final wordsInserts = RegExp(
          r'insert into public.words\b',
        ).allMatches(sql).map((m) => m.start).toList();
        final confusionsInsert = sql.indexOf(
          'insert into public.word_confusions',
        );

        expect(wordsInserts, hasLength(2));
        expect(confusionsInsert, greaterThan(wordsInserts.last));
      },
    );
  });

  group('confused_word_id', () {
    test('links a confusion to the catalogue word it names', () {
      // The app interference rule reads `confused_word_id` first; leaving it
      // null makes the pair depend on the lemma string surviving a rename.
      final sql = emitWords([
        catalogued('talante', confusedWith: ['tajante']),
        catalogued('tajante', confusedWith: ['talante']),
      ]);
      final rows = confusionRows(sql);

      expect(rows, hasLength(2));
      expect(rows.first['confused_with'], 'tajante');
      expect(rows.first['confused_word_id'], deterministicWordId('tajante'));
      expect(rows.last['confused_word_id'], deterministicWordId('talante'));
    });

    test('keeps null when the confusable word is not in the catalogue', () {
      final rows = confusionRows(
        emitWords([
          catalogued('talante', confusedWith: ['semblante']),
        ]),
      );

      expect(rows.single['confused_with'], 'semblante');
      expect(rows.single.containsKey('confused_word_id'), isTrue);
      expect(rows.single['confused_word_id'], isNull);
    });

    test('matches the lemma without case or accents', () {
      final rows = confusionRows(
        emitWords([
          catalogued('cesión', confusedWith: ['Concesion']),
          catalogued('concesión'),
        ]),
      );

      expect(rows.first['confused_word_id'], deterministicWordId('concesion'));
    });

    test('matches a family member of a catalogue word', () {
      final rows = confusionRows(
        emitWords([
          catalogued('conciso', confusedWith: ['preciso']),
          catalogued('precisamente', family: ['preciso']),
        ]),
      );

      expect(
        rows.first['confused_word_id'],
        deterministicWordId('precisamente'),
      );
    });

    test('never links a confusion to the word that declares it', () {
      final rows = confusionRows(
        emitWords([
          catalogued('ensayar', family: ['ensayo'], confusedWith: ['ensayo']),
        ]),
      );

      expect(rows.single['confused_word_id'], isNull);
    });

    test('uses the id the word row carries, authored or derived', () {
      final tajante = Word.fromMap(
        validWordMap()
          ..['id'] = 'a0000000-0000-4000-8000-000000000001'
          ..['slug'] = 'tajante'
          ..['lemma'] = 'tajante'
          ..['syllables'] = ['tajante']
          ..['stressed_syllable'] = 1,
      );
      final rows = confusionRows(
        emitWords([catalogued('talante', confusedWith: ['tajante']), tajante]),
      );

      expect(
        rows.first['confused_word_id'],
        'a0000000-0000-4000-8000-000000000001',
      );
    });

    test('the committed seed links every pair the catalogue declares', () {
      // The defect this replaces shipped 352 rows with a null link, nine of
      // them naming a published lemma.
      final rows = confusionRows(seedSql);
      final ids = {
        for (final word in parseSeedRows(seedSql)['words']!)
          word['id']! as String,
      };
      final linked = rows.where((r) => r['confused_word_id'] != null);

      expect(linked, isNotEmpty);
      for (final row in linked) {
        expect(ids, contains(row['confused_word_id']));
        expect(row['confused_word_id'], isNot(row['word_id']));
      }
    });
  });
}
