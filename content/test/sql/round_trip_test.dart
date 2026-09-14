import 'dart:io';

import 'package:content/src/model/word.dart';
import 'package:content/src/model/word_yaml.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:content/src/sql/seed_emitter.dart';
import 'package:content/src/sql/seed_importer.dart';
import 'package:content/src/sql/seed_sql_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/validation_harness.dart';

final String seedPath = p.normalize(
  p.join(Directory.current.path, '..', 'supabase', 'seed.sql'),
);

void main() {
  final seedSql = File(seedPath).readAsStringSync();

  group('parseSeedRows', () {
    test('reads the eight seed words with their children', () {
      final rows = parseSeedRows(seedSql);

      expect(rows['words'], hasLength(8));
      expect(rows['word_confusions'], hasLength(16));
      expect(rows['exercises'], hasLength(24));
      expect(rows['exercise_options'], hasLength(72));
      expect(rows['readings'], hasLength(24));
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
  });
}
