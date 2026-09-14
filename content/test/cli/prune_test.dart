import 'package:content/src/cli/prune.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// The canonical word with the distractor type of every option of the
/// exercises named by [typeByPosition] rewritten, so a test can decide which
/// exercise carries the only `register` or the only `paronym`.
Map<String, Object?> wordWithTypes(Map<int, String> typeByPosition) {
  final map = validWordMap();
  for (final exercise
      in (map['exercises']! as List<Object?>).cast<Map<String, Object?>>()) {
    final replacement = typeByPosition[exercise['position']];
    if (replacement == null) continue;
    for (final option
        in (exercise['options']! as List<Object?>)
            .cast<Map<String, Object?>>()) {
      if (option['is_correct'] == true) continue;
      option['distractor_type'] = replacement;
    }
  }
  return map;
}

List<int> positionsOf(Map<String, Object?> word) => [
  for (final exercise
      in (word['exercises']! as List<Object?>).cast<Map<String, Object?>>())
    exercise['position']! as int,
];

List<String> sentencesOf(Map<String, Object?> word) => [
  for (final exercise
      in (word['exercises']! as List<Object?>).cast<Map<String, Object?>>())
    exercise['sentence']! as String,
];

void main() {
  group('failedExercisePositions', () {
    test('reads the exercise numbers a failures file names', () {
      final positions = failedExercisePositions([
        'exercise 5: pass a (reviewer-a1-r2) flagged the item as ambiguous',
        'exercise 2: pass b (reviewer-b1-r2) flagged the item as ambiguous',
        'exercise 5: pass b (reviewer-b1-r2) flagged the item as ambiguous',
      ]);

      expect(positions, {2, 5});
    });

    test('reads a reason that names a chosen distractor', () {
      const reason =
          'exercise 3: pass a (reviewer-a3-r2) chose "sagaz" (near_synonym) '
          'instead of "perspicaz" — the sentence does not force a single '
          'answer, or the distractor is too defensible';

      expect(failedExercisePositions([reason]), {3});
    });

    test('ignores a reason that names no exercise', () {
      expect(
        failedExercisePositions([
          'needs two passes with different option orderings; got only a',
        ]),
        isEmpty,
      );
    });
  });

  group('parseFailureReasons', () {
    test('reads the reasons content:gate-apply wrote', () {
      final reasons = parseFailureReasons(<String, Object?>{
        'word': 'perspicaz',
        'reasons': <Object?>['exercise 1: pass a (reviewer-a1-r2) did not answer'],
      });

      expect(reasons, hasLength(1));
    });

    test('rejects a file without a reasons list', () {
      expect(
        () => parseFailureReasons(<String, Object?>{'word': 'perspicaz'}),
        throwsFormatException,
      );
    });

    test('rejects a reason that is not a string', () {
      expect(
        () => parseFailureReasons(<String, Object?>{
          'reasons': <Object?>[7],
        }),
        throwsFormatException,
      );
    });
  });

  group('planPrune', () {
    test('drops exactly the exercises the gate named', () {
      final plan = planPrune(
        slug: 'perspicaz',
        word: validWordMap(),
        failed: {4},
      );

      expect(plan.refusals, isEmpty);
      expect(plan.dropped, [4]);
      expect(plan.kept, 7);
      expect(sentencesOf(plan.word!), hasLength(7));
      expect(
        sentencesOf(plan.word!),
        isNot(contains(sentencesOf(validWordMap())[3])),
      );
    });

    test('renumbers the survivors 1..n', () {
      final plan = planPrune(
        slug: 'perspicaz',
        word: validWordMap(),
        failed: {2, 6},
      );

      expect(positionsOf(plan.word!), [1, 2, 3, 4, 5, 6]);
    });

    test('keeps the survivors in order and touches nothing else', () {
      final original = validWordMap();
      final plan = planPrune(
        slug: 'perspicaz',
        word: validWordMap(),
        failed: {1},
      );

      expect(sentencesOf(plan.word!), sentencesOf(original).sublist(1));
      expect(plan.word!['readings'], original['readings']);
      expect(plan.word!['status'], original['status']);
      expect(plan.word!['confusions'], original['confusions']);
    });

    test('refuses to drop below the six-exercise floor', () {
      final plan = planPrune(
        slug: 'perspicaz',
        word: validWordMap(),
        failed: {1, 3, 4},
      );

      expect(plan.word, isNull);
      expect(plan.refusals.join(), contains('5'));
      expect(plan.refusals.join(), contains('6'));
    });

    test('refuses when the survivors lose the register distractor', () {
      // Only exercise 2 carries `register`, and the gate named it.
      final word = wordWithTypes({5: 'near_synonym', 7: 'near_synonym'});
      final plan = planPrune(slug: 'perspicaz', word: word, failed: {2});

      expect(plan.word, isNull);
      expect(plan.refusals.join(), contains('register'));
    });

    test('refuses when the survivors lose the paronym distractor', () {
      // Only exercise 8 keeps a `paronym` after this rewrite.
      final word = wordWithTypes({
        1: 'near_synonym',
        2: 'register',
        3: 'near_synonym',
        4: 'near_synonym',
        5: 'register',
        6: 'near_synonym',
        7: 'register',
      });
      final plan = planPrune(slug: 'perspicaz', word: word, failed: {8});

      expect(plan.word, isNull);
      expect(plan.refusals.join(), contains('paronym'));
    });

    test('refuses an exercise the word does not have', () {
      final plan = planPrune(
        slug: 'perspicaz',
        word: validWordMap(),
        failed: {9},
      );

      expect(plan.word, isNull);
      expect(plan.refusals.join(), contains('9'));
    });

    test('reports both reasons when a prune breaks count and coverage', () {
      final word = wordWithTypes({5: 'near_synonym', 7: 'near_synonym'});
      final plan = planPrune(
        slug: 'perspicaz',
        word: word,
        failed: {1, 2, 3},
      );

      expect(plan.refusals, hasLength(2));
    });

    test('an empty failure set leaves the word exactly as it was', () {
      final plan = planPrune(
        slug: 'perspicaz',
        word: validWordMap(),
        failed: const {},
      );

      expect(plan.refusals, isEmpty);
      expect(plan.dropped, isEmpty);
      expect(plan.word, validWordMap());
    });
  });
}
