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

    test('escapes apostrophes in literals', () {
      expect(sqlLiteral("l'ami"), "'l''ami'");
      expect(sqlLiteral(null), 'null');
    });
  });
}
