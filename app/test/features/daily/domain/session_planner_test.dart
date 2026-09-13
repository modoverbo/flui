import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final today = day(13);

  List<Word> catalog(int count, {int startSort = 100}) => [
    for (var i = 0; i < count; i++)
      buildWord(id: 'c$i', lemma: 'candidata$i', sortOrder: startSort + i),
  ];

  List<DueReview> reviews(int count) => [
    for (var i = 0; i < count; i++)
      DueReview(
        progress: buildProgress(
          wordId: 'r$i',
          nextDueOn: today.addDays(-(i % 3)),
          ladderStep: i % 5,
        ),
        sortOrder: i,
      ),
  ];

  group('SessionPlanner budget table (learning-method §1)', () {
    final cases =
        <(int budget, int due, int planned, bool afianzar, int newWords)>[
          (5, 0, 0, false, 0),
          (5, 4, 4, false, 0),
          (5, 12, 10, true, 0),
          (10, 0, 0, false, 1),
          (10, 4, 4, false, 1),
          (10, 12, 12, true, 0),
          (20, 2, 2, false, 2),
          (20, 22, 22, true, 1),
          (30, 0, 0, false, 3),
          (30, 32, 32, true, 1),
          (30, 40, 40, true, 1),
        ];
    for (final (budget, due, planned, afianzar, newWords) in cases) {
      test('$budget min, $due due -> $planned reviews, afianzar $afianzar, '
          '$newWords new', () {
        final plan = SessionPlanner.plan(
          budgetMinutes: budget,
          today: today,
          dueReviews: reviews(due),
          candidates: catalog(5),
          recentIntroductions: const [],
        );

        expect(plan.reviewWordIds, hasLength(planned));
        expect(plan.afianzar, afianzar);
        expect(plan.newWordIds, hasLength(newWords));
        expect(plan.isEmpty, planned == 0 && newWords == 0);
        expect(plan.budgetMinutes, budget);
      });
    }
  });

  group('review order', () {
    test('oldest due first, then lower ladder step, then sort order', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: [
          DueReview(
            progress: buildProgress(wordId: 'b', nextDueOn: day(12)),
            sortOrder: 2,
          ),
          DueReview(
            progress: buildProgress(
              wordId: 'c',
              nextDueOn: day(10),
              ladderStep: 2,
            ),
            sortOrder: 3,
          ),
          DueReview(
            progress: buildProgress(
              wordId: 'a',
              nextDueOn: day(10),
              ladderStep: 1,
            ),
            sortOrder: 9,
          ),
          DueReview(
            progress: buildProgress(wordId: 'd', nextDueOn: day(12)),
            sortOrder: 1,
          ),
        ],
        candidates: const [],
        recentIntroductions: const [],
        warmUpSize: 0,
      );

      expect(plan.reviewWordIds, ['a', 'c', 'd', 'b']);
    });

    test('reviews that do not fit the budget stay for tomorrow', () {
      final due = reviews(12);
      final plan = SessionPlanner.plan(
        budgetMinutes: 5,
        today: today,
        dueReviews: due,
        candidates: const [],
        recentIntroductions: const [],
        warmUpSize: 0,
      );

      final ordered = SessionPlanner.orderReviews(due);
      expect(plan.reviewWordIds, ordered.take(10).map((r) => r.wordId));
    });

    test('warm-up: up to two easy planned reviews go first', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: [
          DueReview(
            progress: buildProgress(wordId: 'hard', nextDueOn: day(10)),
            sortOrder: 1,
          ),
          DueReview(
            progress: buildProgress(
              wordId: 'easy1',
              nextDueOn: day(12),
              ladderStep: 2,
              lastGrade: Grade.good,
            ),
            sortOrder: 2,
          ),
          DueReview(
            progress: buildProgress(
              wordId: 'again',
              nextDueOn: day(11),
              lastGrade: Grade.again,
            ),
            sortOrder: 3,
          ),
          DueReview(
            progress: buildProgress(
              wordId: 'easy2',
              nextDueOn: day(13),
              ladderStep: 4,
              lastGrade: Grade.good,
            ),
            sortOrder: 4,
          ),
          DueReview(
            progress: buildProgress(
              wordId: 'easy3',
              nextDueOn: day(13),
              ladderStep: 1,
              lastGrade: Grade.good,
            ),
            sortOrder: 5,
          ),
        ],
        candidates: const [],
        recentIntroductions: const [],
      );

      expect(plan.warmUpCount, 2);
      expect(plan.reviewWordIds, ['easy2', 'easy1', 'hard', 'again', 'easy3']);
    });
  });

  group('new words and the interference rule (§7)', () {
    test('walks candidates in sort order', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 30,
        today: today,
        dueReviews: const [],
        candidates: [
          buildWord(id: 'third', sortOrder: 3),
          buildWord(id: 'first'),
          buildWord(id: 'fourth', sortOrder: 4),
          buildWord(id: 'second', sortOrder: 2),
        ],
        recentIntroductions: const [],
      );

      expect(plan.newWordIds, ['first', 'second', 'third']);
    });

    test('skips candidates confusable with a word introduced in 7 days', () {
      final perspicaz = buildWord(id: 'perspicaz', lemma: 'perspicaz');
      final suspicaz = buildWord(
        id: 'suspicaz',
        lemma: 'suspicaz',
        confusions: [confusion(wordId: 'suspicaz', confusedWith: 'perspicaz')],
      );
      final zanjar = buildWord(id: 'zanjar', lemma: 'zanjar', sortOrder: 2);

      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [suspicaz, zanjar],
        recentIntroductions: [perspicaz],
      );

      expect(plan.newWordIds, ['zanjar']);
    });

    test('never picks two confusable words on the same day', () {
      final perspicaz = buildWord(
        id: 'perspicaz',
        lemma: 'perspicaz',
        confusions: [
          confusion(
            wordId: 'perspicaz',
            confusedWith: 'otra',
            confusedWordId: 'perspicuo',
          ),
        ],
      );
      final perspicuo = buildWord(
        id: 'perspicuo',
        lemma: 'perspicuo',
        sortOrder: 2,
      );
      final zanjar = buildWord(id: 'zanjar', lemma: 'zanjar', sortOrder: 3);

      final plan = SessionPlanner.plan(
        budgetMinutes: 20,
        today: today,
        dueReviews: const [],
        candidates: [perspicaz, perspicuo, zanjar],
        recentIntroductions: const [],
      );

      expect(plan.newWordIds, ['perspicaz', 'zanjar']);
    });

    test('afianzar keeps at most one new word', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 30,
        today: today,
        dueReviews: reviews(32),
        candidates: catalog(5),
        recentIntroductions: const [],
      );

      expect(plan.afianzar, isTrue);
      expect(plan.newWordIds, hasLength(1));
    });
  });

  group('SessionPlanInputs.derive', () {
    test('splits the catalog and progress into planner inputs', () {
      final words = [
        buildWord(id: 'due'),
        buildWord(id: 'later', sortOrder: 2),
        buildWord(id: 'fresh', sortOrder: 3),
        buildWord(id: 'recent', sortOrder: 4),
        buildWord(id: 'old', sortOrder: 5),
      ];
      final progress = [
        buildProgress(wordId: 'due', nextDueOn: today, introducedOn: day(1)),
        buildProgress(
          wordId: 'later',
          nextDueOn: day(20),
          introducedOn: day(1),
        ),
        buildProgress(
          wordId: 'recent',
          state: WordState.nueva,
          introducedOn: day(7),
          nextDueOn: day(20),
        ),
        buildProgress(wordId: 'old', introducedOn: day(6), nextDueOn: day(20)),
      ];

      final inputs = SessionPlanInputs.derive(
        catalog: words,
        progress: progress,
        today: today,
      );

      expect(inputs.dueReviews.map((r) => r.wordId), ['due']);
      expect(inputs.dueReviews.single.sortOrder, 1);
      expect(inputs.candidates.map((w) => w.id), ['fresh']);
      expect(inputs.recentIntroductions.map((w) => w.id), ['recent']);
    });

    test('ignores progress rows of words missing from the catalog', () {
      final inputs = SessionPlanInputs.derive(
        catalog: const [],
        progress: [WordProgress.introduced(wordId: 'gone', today: day(1))],
        today: today,
      );

      expect(inputs.dueReviews, isEmpty);
    });

    test('isAfianzar recomputes the flag from a saved session', () {
      expect(SessionPlanner.isAfianzar(minutes: 10, reviewCount: 12), isTrue);
      expect(SessionPlanner.isAfianzar(minutes: 10, reviewCount: 10), isFalse);
    });
  });

  test('LocalDate helper sanity for the planner window', () {
    expect(today.addDays(-6), LocalDate(2026, 9, 7));
  });
}
