import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
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

  group('the semantic-set rule (§7)', () {
    test('skips a candidate of a set introduced in the last 7 days', () {
      final contundente = buildWord(
        id: 'contundente',
        lemma: 'contundente',
        semanticSetId: 'fuerza-de-la-afirmacion',
      );
      final matizar = buildWord(
        id: 'matizar',
        lemma: 'matizar',
        sortOrder: 2,
        semanticSetId: 'fuerza-de-la-afirmacion',
      );
      final zanjar = buildWord(id: 'zanjar', lemma: 'zanjar', sortOrder: 3);

      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [matizar, zanjar],
        recentIntroductions: [contundente],
      );

      expect(plan.newWordIds, ['zanjar']);
    });

    test('never picks two words of one set on the same day', () {
      final contundente = buildWord(
        id: 'contundente',
        semanticSetId: 'fuerza-de-la-afirmacion',
      );
      final matizar = buildWord(
        id: 'matizar',
        sortOrder: 2,
        semanticSetId: 'fuerza-de-la-afirmacion',
      );
      final zanjar = buildWord(id: 'zanjar', sortOrder: 3);

      final plan = SessionPlanner.plan(
        budgetMinutes: 20,
        today: today,
        dueReviews: const [],
        candidates: [contundente, matizar, zanjar],
        recentIntroductions: const [],
      );

      expect(plan.newWordIds, ['contundente', 'zanjar']);
    });

    test('two words of one theme are still introducible together', () {
      final a = buildWord(id: 'a', themeIds: const ['reuniones']);
      final b = buildWord(id: 'b', sortOrder: 2, themeIds: const ['reuniones']);

      final plan = SessionPlanner.plan(
        budgetMinutes: 20,
        today: today,
        dueReviews: const [],
        candidates: [a, b],
        recentIntroductions: const [],
      );

      expect(plan.newWordIds, ['a', 'b']);
    });
  });

  group('the theme filter touches new words only', () {
    final themed = buildWord(
      id: 'themed',
      sortOrder: 5,
      themeIds: const ['reuniones'],
    );
    final other = buildWord(id: 'other', themeIds: const ['negociacion']);

    test('a new word comes from the chosen theme, not from sort order', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [other, themed],
        recentIntroductions: const [],
        themeId: 'reuniones',
        neighbourThemeIds: const ['negociacion'],
      );

      expect(plan.newWordIds, ['themed']);
      expect(plan.themeId, 'reuniones');
      expect(plan.themeFallback, isNull);
    });

    test('the due-review queue stays global and keeps its order', () {
      final due = reviews(6);

      final themedPlan = SessionPlanner.plan(
        budgetMinutes: 20,
        today: today,
        dueReviews: due,
        candidates: [other, themed],
        recentIntroductions: const [],
        themeId: 'reuniones',
      );
      final globalPlan = SessionPlanner.plan(
        budgetMinutes: 20,
        today: today,
        dueReviews: due,
        candidates: [other, themed],
        recentIntroductions: const [],
      );

      expect(themedPlan.reviewWordIds, globalPlan.reviewWordIds);
      expect(themedPlan.warmUpCount, globalPlan.warmUpCount);
    });

    test('the theme changes neither the slots nor the afianzar flag', () {
      final due = reviews(32);

      final themedPlan = SessionPlanner.plan(
        budgetMinutes: 30,
        today: today,
        dueReviews: due,
        candidates: catalog(5),
        recentIntroductions: const [],
        themeId: 'reuniones',
      );
      final globalPlan = SessionPlanner.plan(
        budgetMinutes: 30,
        today: today,
        dueReviews: due,
        candidates: catalog(5),
        recentIntroductions: const [],
      );

      expect(themedPlan.afianzar, globalPlan.afianzar);
      expect(themedPlan.reviewWordIds, hasLength(32));
    });
  });

  group('the exhaustion cascade never leaves an empty day', () {
    final neighbourWord = buildWord(
      id: 'neighbour',
      sortOrder: 4,
      themeIds: const ['negociacion'],
    );
    final strangerWord = buildWord(
      id: 'stranger',
      sortOrder: 9,
      themeIds: const ['cocina'],
    );

    test('(a) themed recombination over the words already in practica', () {
      final known = buildWord(id: 'known', themeIds: const ['reuniones']);

      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [neighbourWord, strangerWord],
        recentIntroductions: const [],
        themeId: 'reuniones',
        practiceWords: [known],
        neighbourThemeIds: const ['negociacion'],
      );

      expect(plan.newWordIds, isEmpty);
      expect(plan.recombinationWordIds, ['known']);
      expect(plan.themeFallback, ThemeFallback.themedPractice);
      expect(plan.isEmpty, isFalse);
      expect(plan.emptyReason, isNull);
    });

    test('(b) the nearest neighbour theme when nothing is in practica', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [neighbourWord, strangerWord],
        recentIntroductions: const [],
        themeId: 'reuniones',
        neighbourThemeIds: const ['negociacion'],
      );

      expect(plan.newWordIds, ['neighbour']);
      expect(plan.themeFallback, ThemeFallback.neighbourTheme);
      expect(plan.fallbackThemeId, 'negociacion');
    });

    test('(c) the global next word when there is no neighbour left', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [strangerWord],
        recentIntroductions: const [],
        themeId: 'reuniones',
        neighbourThemeIds: const ['negociacion'],
      );

      expect(plan.newWordIds, ['stranger']);
      expect(plan.themeFallback, ThemeFallback.globalCatalog);
      // The copy names where the word does come from, when it comes from
      // somewhere: "Te traigo una de {otro}".
      expect(plan.fallbackThemeId, 'cocina');
    });

    test('a word with no theme at all is still offered, unnamed', () {
      final untagged = buildWord(id: 'untagged', sortOrder: 9);

      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [untagged],
        recentIntroductions: const [],
        themeId: 'reuniones',
      );

      expect(plan.newWordIds, ['untagged']);
      expect(plan.themeFallback, ThemeFallback.globalCatalog);
      expect(plan.fallbackThemeId, isNull);
    });

    test('the cascade still respects the interference rules', () {
      final blocked = buildWord(
        id: 'blocked',
        lemma: 'matizar',
        semanticSetId: 'fuerza-de-la-afirmacion',
      );
      final contundente = buildWord(
        id: 'contundente',
        lemma: 'contundente',
        semanticSetId: 'fuerza-de-la-afirmacion',
      );

      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: [blocked],
        recentIntroductions: [contundente],
        themeId: 'reuniones',
      );

      expect(plan.newWordIds, isEmpty);
      expect(plan.emptyReason, EmptyPlanReason.allReviewsDone);
    });

    test('recombination never exceeds the slots the theme left empty', () {
      final known = [
        for (var i = 0; i < 5; i++)
          buildWord(id: 'k$i', sortOrder: i + 1, themeIds: const ['reuniones']),
      ];

      final plan = SessionPlanner.plan(
        budgetMinutes: 30,
        today: today,
        dueReviews: const [],
        candidates: const [],
        recentIntroductions: const [],
        themeId: 'reuniones',
        practiceWords: known,
      );

      expect(plan.recombinationWordIds, ['k0', 'k1', 'k2']);
    });

    test('a themed day with nothing anywhere is honestly empty', () {
      final plan = SessionPlanner.plan(
        budgetMinutes: 10,
        today: today,
        dueReviews: const [],
        candidates: const [],
        recentIntroductions: const [],
        themeId: 'reuniones',
      );

      expect(plan.isEmpty, isTrue);
      expect(plan.emptyReason, EmptyPlanReason.noCandidatesLeft);
      expect(plan.themeFallback, isNull);
    });
  });

  group('SessionPlanInputs.derive with themes', () {
    test('collects the words already in practica and the neighbours', () {
      final reuniones = buildTheme(slug: 'reuniones');
      final negociacion = buildTheme(slug: 'negociacion', sortOrder: 2);
      final words = [
        buildWord(id: 'known', themeIds: const ['reuniones', 'negociacion']),
        buildWord(
          id: 'nueva',
          sortOrder: 2,
          themeIds: const ['reuniones', 'negociacion'],
        ),
        buildWord(id: 'fresh', sortOrder: 3, themeIds: const ['negociacion']),
      ];
      final progress = [
        buildProgress(wordId: 'known', nextDueOn: day(20)),
        buildProgress(
          wordId: 'nueva',
          state: WordState.nueva,
          nextDueOn: day(20),
        ),
      ];

      final inputs = SessionPlanInputs.derive(
        catalog: words,
        progress: progress,
        today: today,
        themes: [reuniones, negociacion],
        themeId: 'reuniones',
      );

      expect(inputs.practiceWords.map((w) => w.id), ['known']);
      expect(inputs.neighbourThemeIds, ['negociacion']);
    });

    test('no theme means no neighbours and no practice list', () {
      final inputs = SessionPlanInputs.derive(
        catalog: [buildWord(id: 'a')],
        progress: [buildProgress(wordId: 'a', nextDueOn: day(20))],
        today: today,
      );

      expect(inputs.neighbourThemeIds, isEmpty);
      expect(inputs.practiceWords, isEmpty);
    });
  });

  test('LocalDate helper sanity for the planner window', () {
    expect(today.addDays(-6), LocalDate(2026, 9, 7));
  });
}
