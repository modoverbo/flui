import 'dart:io';

import 'package:flui/features/training/data/fake/seed_challenges.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/form_recall_prompt.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed/seed_parser.dart';
import '../../tool/seed_to_fixture.dart'
    show renderSeedChallengesFixture, renderSeedFixture;

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

    test('reads the word_themes select-from-values statement', () {
      const sql = '''
insert into public.word_themes (word_id, theme_id, relevance, sort_order)
select w.id, t.id, v.relevance, w.sort_order
from (values
  ('perspicaz', 'reuniones', 3),
  ('perspicaz', 'entrevistas', 1)
) as v (word_slug, theme_slug, relevance)
join public.words w on w.slug = v.word_slug
join public.themes t on t.slug = v.theme_slug;
''';

      expect(parseSeedRows(sql)['word_themes'], [
        {'word_slug': 'perspicaz', 'theme_slug': 'reuniones', 'relevance': 3},
        {'word_slug': 'perspicaz', 'theme_slug': 'entrevistas', 'relevance': 1},
      ]);
    });

    test('groups the theme slugs of a word in seed order', () {
      const sql = '''
insert into public.word_themes (word_id, theme_id, relevance, sort_order)
select w.id, t.id, v.relevance, w.sort_order
from (values
  ('perspicaz', 'reuniones', 3),
  ('perspicaz', 'entrevistas', 1),
  ('zanjar', 'negociacion', 3)
) as v (word_slug, theme_slug, relevance)
join public.words w on w.slug = v.word_slug
join public.themes t on t.slug = v.theme_slug;
''';

      expect(parseSeedWordThemeSlugs(sql), {
        'perspicaz': ['reuniones', 'entrevistas'],
        'zanjar': ['negociacion'],
      });
    });

    test('a word absent from word_themes carries no entry', () {
      const sql = '''
insert into public.word_themes (word_id, theme_id, relevance, sort_order)
select w.id, t.id, v.relevance, w.sort_order
from (values
  ('perspicaz', 'reuniones', 3)
) as v (word_slug, theme_slug, relevance)
join public.words w on w.slug = v.word_slug
join public.themes t on t.slug = v.theme_slug;
''';

      final slugs = parseSeedWordThemeSlugs(sql);

      // 'zanjar' never appears in word_themes: callers must default it to
      // an empty list themselves (seed_themes.dart does, via `?? const []`).
      expect(slugs.containsKey('zanjar'), isFalse);
      expect(slugs['perspicaz'], ['reuniones']);
    });
  });

  group('renderSeedFixture', () {
    Word wordWith({
      List<String> family = const [],
      List<String> collocations = const [],
    }) => Word(
      id: 'w',
      slug: 'perspicaz',
      lemma: 'perspicaz',
      partOfSpeech: PartOfSpeech.adjetivo,
      syllables: const ['pers', 'pi', 'caz'],
      stressedSyllable: 3,
      explanation: 'x',
      exampleSentence: 'y',
      register: WordRegister.neutral,
      pedantryRisk: 1,
      sortOrder: 1,
      family: family,
      collocations: collocations,
    );

    test('omits a list argument that matches the constructor default', () {
      // `dart analyze --fatal-infos` runs over the generated fixture, and
      // `family: []` on a word with no derivations is a redundant argument.
      final rendered = renderSeedFixture([wordWith()]);

      expect(rendered, isNot(contains('family: []')));
      expect(rendered, isNot(contains('collocations: []')));
    });

    test('still renders a list that carries something', () {
      final rendered = renderSeedFixture([
        wordWith(family: const ['perspicacia']),
      ]);

      expect(rendered, contains("family: ['perspicacia']"));
    });

    test('generates the word to theme-slug map from the seed', () {
      // The links used to be a hand-written copy of the eight starter words,
      // which silently left every later word unreachable by theme.
      final rendered = renderSeedFixture(
        [wordWith()],
        themeSlugs: const {
          'perspicaz': ['reuniones', 'entrevistas'],
        },
      );

      expect(rendered, contains('const seedWordThemeSlugs'));
      expect(rendered, contains("'perspicaz': ['reuniones', 'entrevistas'],"));
    });

    test('omits a themeless word from the theme-slug map entirely', () {
      // A `{'perspicaz': []}` entry would be truthful but wasteful: every
      // caller already treats a missing key as "no theme" (`?? const []`).
      final rendered = renderSeedFixture([wordWith()]);

      expect(rendered, contains('const seedWordThemeSlugs'));
      expect(rendered, isNot(contains("'perspicaz':")));
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
      // How many words the catalog holds is not an invariant — it grows every
      // authoring round. That the fixture holds *the* approved words is, and
      // the sync test above is what proves it.
      expect(seedWords, isNotEmpty);
      for (final word in seedWords) {
        // A word is authored with 8 exercises (docs/learning-method requires a
        // fresh sentence for every encounter). `content:prune` may drop the
        // items the adversarial gate found ambiguous, down to a floor of 6 —
        // content/lib/src/validation/structural.dart is where that is enforced.
        expect(
          word.exercises.length,
          inInclusiveRange(6, 8),
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

  group('parseSeedChallenges', () {
    test('reads a published challenge with its behavior codes', () {
      const sql = '''
insert into public.challenges
  (id, slug, purpose, diagnosis_slot, skill, mode, difficulty, prompt, cue,
   focus, focus_behaviors, transfer_prompts, target_seconds, sort_order, published)
values
  ('c1', 'habla-clara-1', 'training', null, 'thinking', 'think_and_speak',
   1, 'Cuéntame algo, en detalle.', 'Empieza por el principio.',
   'Ordena tus ideas.', array['no_clear_structure', 'ordered_ideas']::text[],
   array['Ahora cuéntame otra cosa.']::text[], 20, 1, true);
''';

      final challenges = parseSeedChallenges(sql);

      expect(challenges, hasLength(1));
      final challenge = challenges.single;
      expect(challenge.purpose, ChallengePurpose.training);
      expect(challenge.mode, TrainingMode.thinkAndSpeak);
      expect(challenge.focusBehaviors, [
        BehaviorCode.noClearStructure,
        BehaviorCode.orderedIdeas,
      ]);
    });

    test('drops an unpublished challenge', () {
      const sql = '''
insert into public.challenges
  (id, slug, purpose, diagnosis_slot, skill, mode, difficulty, prompt, cue,
   focus, focus_behaviors, transfer_prompts, target_seconds, sort_order, published)
values
  ('c1', 'borrador-1', 'training', null, 'voice', 'master_your_voice',
   1, 'Cuéntame algo, en detalle.', null,
   'Ritmo constante.', array['pace_fast']::text[],
   array['Sigue contando.']::text[], 20, 1, false);
''';

      expect(parseSeedChallenges(sql), isEmpty);
    });
  });

  group('renderSeedChallengesFixture', () {
    Challenge challengeWith({int? diagnosisSlot, TrainingMode? mode}) =>
        Challenge(
          id: 'c1',
          slug: 'habla-clara-1',
          purpose: diagnosisSlot == null
              ? ChallengePurpose.training
              : ChallengePurpose.diagnosis,
          skill: Skill.thinking,
          mode: mode,
          difficulty: 1,
          prompt: 'Cuéntame algo, en detalle.',
          focus: 'Ordena tus ideas.',
          focusBehaviors: const [BehaviorCode.noClearStructure],
          transferPrompts: const ['Ahora cuéntame otra cosa.'],
          targetDuration: const Duration(seconds: 20),
          sortOrder: 1,
          diagnosisSlot: diagnosisSlot,
        );

    test('omits diagnosisSlot/mode when absent', () {
      final rendered = renderSeedChallengesFixture([challengeWith()]);

      expect(rendered, isNot(contains('diagnosisSlot:')));
      expect(rendered, isNot(contains('mode:')));
    });

    test('renders diagnosisSlot and mode when present', () {
      final rendered = renderSeedChallengesFixture([
        challengeWith(diagnosisSlot: 2, mode: TrainingMode.masterYourVoice),
      ]);

      expect(rendered, contains('diagnosisSlot: 2'));
      expect(rendered, contains('mode: TrainingMode.masterYourVoice'));
    });
  });

  group('fake training-content fixture', () {
    final seed = File('../supabase/seed.sql');

    test('is in sync with supabase/seed.sql', () {
      expect(seed.existsSync(), isTrue, reason: 'Run tests from app/.');
      final parsed = parseSeedChallenges(seed.readAsStringSync());

      expect(seedChallenges, parsed);
    });

    test('every published challenge has a valid target duration', () {
      expect(seedChallenges, isNotEmpty);
      for (final challenge in seedChallenges) {
        expect(
          challenge.targetDuration.inSeconds,
          inInclusiveRange(15, 60),
          reason: challenge.slug,
        );
        expect(
          (challenge.purpose == ChallengePurpose.diagnosis) ==
              (challenge.diagnosisSlot != null),
          isTrue,
          reason: challenge.slug,
        );
        expect(
          (challenge.purpose == ChallengePurpose.training) ==
              (challenge.mode != null),
          isTrue,
          reason: challenge.slug,
        );
      }
    });
  });
}
