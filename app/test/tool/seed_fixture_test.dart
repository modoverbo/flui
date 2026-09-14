import 'dart:io';

import 'package:flui/features/exercises/domain/cloze_exercise.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/domain/form_recall_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed/seed_parser.dart';

void main() {
  group('seed SQL parser', () {
    test('reads strings with escaped quotes, arrays, json and casts', () {
      const sql = '''
-- comment with 'quotes'
insert into public.words (id, lemma, syllables, replaces, published, sort_order)
values ('w', 'o''clock', array['a', 'b']::text[], '[{"before": "x", "after": "y"}]'::jsonb, true, 3);
''';

      final rows = parseSeedRows(sql)['words']!;

      expect(rows.single, {
        'id': 'w',
        'lemma': "o'clock",
        'syllables': ['a', 'b'],
        'replaces': '[{"before": "x", "after": "y"}]',
        'published': true,
        'sort_order': 3,
      });
    });

    test('attaches cross-joined options to the exercise of the CTE', () {
      const sql = '''
with exercise as (
  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)
  values ('e1', 'w', 'Es {{blank}}.', 'h', 'x', 1)
  returning id
)
insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)
select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position
from exercise
cross join (values
    ('a', true, null, null, null, 1),
    ('b', false, 'near_synonym', 'no', 'pista', 2)
) as o (text, is_correct, distractor_type, why_not, hint_specific, position);
''';

      final rows = parseSeedRows(sql);

      expect(rows['exercises']!.single['id'], 'e1');
      expect(rows['exercise_options'], hasLength(2));
      expect(rows['exercise_options']!.last, {
        'exercise_id': 'e1',
        'text': 'b',
        'is_correct': false,
        'distractor_type': 'near_synonym',
        'why_not': 'no',
        'hint_specific': 'pista',
        'position': 2,
      });
    });
  });

  group('fake backend fixture', () {
    final seed = File('../supabase/seed.sql');

    test('is in sync with supabase/seed.sql', () {
      expect(seed.existsSync(), isTrue, reason: 'Run tests from app/.');
      final parsed = parseSeedWords(seed.readAsStringSync());

      expect(seedWords, parsed);
    });

    test('keeps the content invariants of the seed', () {
      expect(seedWords, hasLength(8));
      for (final word in seedWords) {
        // The authoring standard is 8 exercises per word (docs/learning-method
        // requires a fresh sentence for every encounter); older words may still
        // carry fewer while the library is being upgraded.
        expect(
          word.exercises.length,
          greaterThanOrEqualTo(3),
          reason: word.lemma,
        );
        expect(word.readings, hasLength(3), reason: word.lemma);
        expect(word.confusions, isNotEmpty, reason: word.lemma);
        for (final exercise in word.exercises) {
          expect(exercise.options, hasLength(3));
          expect(exercise.options.where((o) => o.isCorrect), hasLength(1));
          expect(
            ClozeExercise.blankToken.allMatches(exercise.sentence),
            hasLength(1),
          );
          for (final distractor in exercise.distractors) {
            expect(distractor.whyNot, isNotNull);
            expect(distractor.hintSpecific, isNotNull);
          }
        }
      }
    });

    test('every example sentence can be masked for form recall', () {
      for (final word in seedWords) {
        expect(
          FormRecallPrompt.forWord(word).hasSentence,
          isTrue,
          reason: word.exampleSentence,
        );
      }
    });

    test('every correct option is a form of its word', () {
      for (final word in seedWords) {
        for (final exercise in word.exercises) {
          expect(
            word.forms.matchesToken(exercise.correctOption.text),
            isTrue,
            reason: exercise.correctOption.text,
          );
        }
      }
    });
  });
}
