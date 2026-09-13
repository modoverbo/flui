import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/session_flow.dart';
import 'package:flui/features/daily/domain/session_step.dart';
import 'package:flui/features/exercises/domain/cloze_attempt_flow.dart';
import 'package:flui/features/exercises/domain/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final today = day(13);
  final words = {
    for (final word in [
      buildWord(id: 'r0'),
      buildWord(id: 'r1', sortOrder: 2),
      buildWord(id: 'n0', sortOrder: 3),
      buildWord(id: 'n1', sortOrder: 4),
      buildWord(id: 'one', sortOrder: 5, exerciseCount: 1),
      buildWord(id: 'noread', sortOrder: 6, readingCount: 0),
    ])
      word.id: word,
  };
  WordProgress reviewed(String id) => buildProgress(
    wordId: id,
    formRecallDone: true,
    productionDone: true,
    nextDueOn: today,
  );
  final reviewProgress = {'r0': reviewed('r0'), 'r1': reviewed('r1')};

  ExerciseAttempt attempt(
    String wordId,
    int position, {
    int attempts = 1,
    bool revealed = false,
    int dayOfMonth = 13,
  }) => ExerciseAttempt(
    exerciseId: '$wordId-e$position',
    wordId: wordId,
    attempts: attempts,
    revealed: revealed,
    grade: Grade.fromOutcome(attempts: attempts, revealed: revealed),
    localDate: day(dayOfMonth),
  );

  SessionFlow build({
    List<String> reviews = const ['r0', 'r1'],
    List<String> newWords = const ['n0'],
    Map<String, WordProgress>? progress,
    List<ExerciseAttempt> attempts = const [],
    Map<String, Word>? catalog,
    int warmUpCount = 2,
  }) => SessionFlow.build(
    reviewWordIds: reviews,
    newWordIds: newWords,
    words: catalog ?? words,
    progress: progress ?? reviewProgress,
    attempts: attempts,
    today: today,
    warmUpCount: warmUpCount,
  );

  const good = ClozeResolution(
    attempts: 1,
    revealed: false,
    grade: Grade.good,
    explanation: '',
    whyNot: [],
  );
  const revealedAnswer = ClozeResolution(
    attempts: 3,
    revealed: true,
    grade: Grade.again,
    explanation: '',
    whyNot: [],
  );

  group('SessionFlow.build', () {
    test('warm-up reviews, then one phase at a time, then a mixed check', () {
      final flow = build();

      expect(flow.steps, const [
        SessionStep.reviewCloze(wordId: 'r0', exerciseId: 'r0-e1'),
        SessionStep.reviewCloze(wordId: 'r1', exerciseId: 'r1-e1'),
        SessionStep.discover(wordId: 'n0'),
        SessionStep.readings(wordId: 'n0', maxCount: 1),
        SessionStep.practiceCloze(wordId: 'n0', exerciseId: 'n0-e1'),
        SessionStep.formRecall(wordId: 'n0', isReview: false),
        SessionStep.readings(wordId: 'n0', fromIndex: 1),
        SessionStep.production(wordId: 'n0', isReview: false),
        SessionStep.finalCheck(wordId: 'n0', exerciseId: 'n0-e2'),
      ]);
      expect(flow.index, 0);
      expect(flow.current, flow.steps.first);
      expect(flow.isFinished, isFalse);
      expect(flow.seeding, isFalse);
    });

    test('acquisition stays blocked, later practice interleaves', () {
      final flow = build(reviews: const [], newWords: const ['n0', 'n1']);

      expect(flow.steps.take(12), const [
        // First contact with a lemma is never chopped up.
        SessionStep.discover(wordId: 'n0'),
        SessionStep.readings(wordId: 'n0', maxCount: 1),
        SessionStep.practiceCloze(wordId: 'n0', exerciseId: 'n0-e1'),
        SessionStep.discover(wordId: 'n1'),
        SessionStep.readings(wordId: 'n1', maxCount: 1),
        SessionStep.practiceCloze(wordId: 'n1', exerciseId: 'n1-e1'),
        // Everything after first contact alternates between the words.
        SessionStep.formRecall(wordId: 'n0', isReview: false),
        SessionStep.formRecall(wordId: 'n1', isReview: false),
        SessionStep.readings(wordId: 'n0', fromIndex: 1),
        SessionStep.readings(wordId: 'n1', fromIndex: 1),
        SessionStep.production(wordId: 'n0', isReview: false),
        SessionStep.production(wordId: 'n1', isReview: false),
      ]);
      expect(flow.steps.skip(12).whereType<FinalCheckStep>(), hasLength(2));
    });

    test('leftover reviews are spread between the acquisition runs', () {
      final extra = {
        for (var i = 2; i < 8; i++)
          'r$i': buildWord(id: 'r$i', sortOrder: 10 + i),
      };
      final flow = build(
        reviews: const ['r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'r7'],
        newWords: const ['n0', 'n1'],
        progress: {
          ...reviewProgress,
          for (final id in extra.keys) id: reviewed(id),
        },
        catalog: {...words, ...extra},
      );

      final steps = flow.steps;
      final firstElige = steps.indexWhere((step) => step is PracticeClozeStep);
      final secondDiscover = steps.indexWhere(
        (step) => step is DiscoverStep && step.wordId == 'n1',
      );
      // n0's run is contiguous, and reviews fill the gap before n1's run.
      expect(
        steps.sublist(firstElige - 2, firstElige + 1).map((s) => s.wordId),
        ['n0', 'n0', 'n0'],
      );
      expect(
        steps
            .sublist(firstElige + 1, secondDiscover)
            .whereType<ReviewClozeStep>(),
        isNotEmpty,
      );
    });

    test("the mixed check shuffles today's reviews in with the new words", () {
      final flow = build(warmUpCount: 0);

      // r0 and r1 are the only reviews: one of them is held back for the
      // mixed check, so the last two steps are not both new-word checks.
      final tail = flow.steps.skip(flow.steps.length - 2).toList();
      expect(tail.map((step) => step.wordId).toSet(), hasLength(2));
      expect(tail.whereType<FinalCheckStep>(), hasLength(1));
      expect(tail.whereType<ReviewClozeStep>(), hasLength(1));
    });

    test('the mixed check order is stable for a day and moves across days', () {
      List<String> tailOn(LocalDate date) => SessionFlow.build(
        reviewWordIds: const ['r0', 'r1'],
        newWordIds: const ['n0'],
        words: words,
        progress: {'r0': reviewed('r0'), 'r1': reviewed('r1')},
        attempts: const [],
        today: date,
        warmUpCount: 0,
      ).steps.map((step) => step.wordId).toList();

      expect(tailOn(day(13)), tailOn(day(13)));
      final orders = {for (var d = 1; d <= 28; d++) tailOn(day(d)).join(',')};
      expect(orders.length, greaterThan(1));
    });

    test('a one-word session still alternates after first contact', () {
      final extra = {'r2': buildWord(id: 'r2', sortOrder: 8)};
      final flow = build(
        reviews: const ['r0', 'r1', 'r2'],
        progress: {...reviewProgress, 'r2': reviewed('r2')},
        catalog: {...words, ...extra},
        warmUpCount: 1,
      );

      final ids = flow.steps.map((step) => step.wordId).toList();
      final elige = flow.steps.indexWhere((s) => s is PracticeClozeStep);
      // The acquisition run is contiguous; a review follows it immediately.
      expect(ids.sublist(elige - 2, elige + 1), ['n0', 'n0', 'n0']);
      expect(ids[elige + 1], startsWith('r'));
    });

    test('a review uses the exercise not seen most recently', () {
      final flow = build(
        reviews: const ['r0'],
        newWords: const [],
        attempts: [
          attempt('r0', 1, dayOfMonth: 12),
          attempt('r0', 2, dayOfMonth: 9),
          attempt('r0', 3, dayOfMonth: 11),
        ],
      );

      expect(
        flow.steps.single,
        const SessionStep.reviewCloze(wordId: 'r0', exerciseId: 'r0-e2'),
      );
    });

    test('never-seen exercises win over seen ones', () {
      final flow = build(
        reviews: const ['r0'],
        newWords: const [],
        attempts: [attempt('r0', 1, dayOfMonth: 1)],
      );

      expect(flow.current!.exerciseId, 'r0-e2');
    });

    test('reviews catch up on missing form recall and production', () {
      final flow = build(
        reviews: const ['r0'],
        newWords: const [],
        progress: {'r0': buildProgress(wordId: 'r0', nextDueOn: today)},
      );

      expect(flow.steps, const [
        SessionStep.reviewCloze(wordId: 'r0', exerciseId: 'r0-e1'),
        SessionStep.formRecall(wordId: 'r0', isReview: true),
        SessionStep.production(wordId: 'r0', isReview: true),
      ]);
    });

    test('nueva reviews only retry the cloze', () {
      final flow = build(
        reviews: const ['r0'],
        newWords: const [],
        progress: {
          'r0': buildProgress(
            wordId: 'r0',
            state: WordState.nueva,
            nextDueOn: today,
          ),
        },
      );

      expect(flow.steps, hasLength(1));
    });

    test('ignores unknown words and words introduced before today', () {
      final flow = build(
        reviews: const ['gone'],
        newWords: const ['n0', 'missing'],
        progress: {'n0': WordProgress.introduced(wordId: 'n0', today: day(10))},
      );

      expect(flow.steps, isEmpty);
      expect(flow.isFinished, isTrue);
    });

    test('a word with a single exercise skips the final check', () {
      final flow = build(reviews: const [], newWords: const ['one']);

      expect(flow.steps.whereType<FinalCheckStep>(), isEmpty);
    });
  });

  group('resume after a reload', () {
    test('skips reviews answered today', () {
      final flow = build(attempts: [attempt('r0', 1)]);

      expect(flow.index, 1);
      expect(flow.current, isA<ReviewClozeStep>());
      expect(flow.current!.wordId, 'r1');
    });

    test('a new word with an answered Elige resumes at Úsala', () {
      final flow = build(
        attempts: [attempt('r0', 1), attempt('r1', 1), attempt('n0', 1)],
        progress: {
          ...reviewProgress,
          'n0': WordProgress.introduced(wordId: 'n0', today: today),
        },
      );

      expect(
        flow.current,
        const SessionStep.formRecall(wordId: 'n0', isReview: false),
      );
      expect(flow.index, 5);
      expect(flow.discoveryCompletedFor('n0'), isFalse);
    });

    test('a row created on leaving Descubre resumes at the first scene', () {
      final flow = build(
        reviews: const [],
        progress: {'n0': WordProgress.introduced(wordId: 'n0', today: today)},
      );

      expect(
        flow.current,
        const SessionStep.readings(wordId: 'n0', maxCount: 1),
      );
      expect(flow.index, 1);
    });

    test('a new word without a row restarts at Descubre', () {
      final flow = build(reviews: const []);

      expect(flow.current, const SessionStep.discover(wordId: 'n0'));
      expect(flow.index, 0);
    });

    test(
      'production done resumes at the final check with a fresh sentence',
      () {
        final flow = build(
          reviews: const [],
          attempts: [attempt('n0', 1)],
          progress: {
            'n0': WordProgress.introduced(
              wordId: 'n0',
              today: today,
            ).copyWith(productionDone: true),
          },
        );

        expect(
          flow.current,
          const SessionStep.finalCheck(wordId: 'n0', exerciseId: 'n0-e2'),
        );
        expect(flow.discoveryCompletedFor('n0'), isTrue);
      },
    );

    test('a word that left nueva today is finished', () {
      final flow = build(
        reviews: const [],
        attempts: [attempt('n0', 1), attempt('n0', 2)],
        progress: {
          'n0': WordProgress.introduced(
            wordId: 'n0',
            today: today,
          ).copyWith(state: WordState.practica, productionDone: true),
        },
      );

      expect(flow.isFinished, isTrue);
      expect(flow.total, 7);
    });

    test('a review form recall survives answering only its cloze', () {
      final owing = buildProgress(wordId: 'r0', nextDueOn: today);
      final flow = build(
        reviews: const ['r0'],
        newWords: const [],
        progress: {'r0': owing},
        attempts: [attempt('r0', 1)],
      );

      // The cloze is behind us; form recall and production are not, because
      // neither form_recall_done nor production_done is set.
      expect(flow.index, 1);
      expect(flow.steps.skip(1), const [
        SessionStep.formRecall(wordId: 'r0', isReview: true),
        SessionStep.production(wordId: 'r0', isReview: true),
      ]);
    });

    test('a review production survives an accepted form recall', () {
      final flow = build(
        reviews: const ['r0'],
        newWords: const [],
        progress: {
          'r0': buildProgress(
            wordId: 'r0',
            formRecallDone: true,
            nextDueOn: today,
          ),
        },
        attempts: [attempt('r0', 1)],
      );

      expect(
        flow.current,
        const SessionStep.production(wordId: 'r0', isReview: true),
      );
    });

    test('a new word form recall is not implied by its Elige answer', () {
      final flow = build(
        reviews: const [],
        attempts: [attempt('n0', 1)],
        progress: {'n0': WordProgress.introduced(wordId: 'n0', today: today)},
      );

      expect(
        flow.current,
        const SessionStep.formRecall(wordId: 'n0', isReview: false),
      );
    });

    test('three reveals today resume in reading mode', () {
      final flow = build(
        attempts: [
          attempt('r0', 1, attempts: 3, revealed: true),
          attempt('r0', 2, attempts: 3, revealed: true),
          attempt('r0', 3, attempts: 3, revealed: true),
        ],
      );

      expect(flow.seeding, isTrue);
      expect(flow.steps.skip(flow.index), const [
        SessionStep.seedingReading(wordId: 'r1'),
      ]);
    });
  });

  group('advancing', () {
    test('completeStep moves the cursor and reports progress', () {
      final flow = build().completeStep().completeStep();

      expect(flow.index, 2);
      expect(flow.position, 3);
      expect(flow.total, 9);
    });

    test('a first-try cloze does not re-queue', () {
      final flow = build().completeCloze(good);

      expect(flow.steps, hasLength(9));
      expect(flow.guard.forcedReveals, 0);
    });

    test('a forced reveal re-queues the word once with an unused sentence', () {
      final flow = build().completeCloze(revealedAnswer);

      expect(
        flow.steps.last,
        const SessionStep.requeueCloze(
          wordId: 'r0',
          exerciseId: 'r0-e2',
          fromReview: true,
        ),
      );
      expect(flow.guard.forcedReveals, 1);
    });

    test('a new word re-queue avoids the sentence reserved for its check', () {
      var flow = build(reviews: const []);
      flow = flow.completeStep().completeStep();
      expect(flow.current, isA<PracticeClozeStep>());

      flow = flow.completeCloze(revealedAnswer);

      expect(
        flow.steps.last,
        const SessionStep.requeueCloze(
          wordId: 'n0',
          exerciseId: 'n0-e3',
          fromReview: false,
        ),
      );
    });

    test('a word is re-queued at most once', () {
      var flow = build(reviews: const ['r0'], newWords: const []);
      flow = flow.completeCloze(revealedAnswer);
      expect(flow.current, isA<RequeueClozeStep>());

      flow = flow.completeCloze(revealedAnswer);

      expect(flow.isFinished, isTrue);
      expect(flow.steps, hasLength(2));
    });

    test('no re-queue when every sentence was shown today', () {
      final flow = build(
        reviews: const ['r0'],
        newWords: const [],
        attempts: [attempt('r0', 2, dayOfMonth: 12)],
        catalog: {
          ...words,
          'r0': buildWord(id: 'r0', exerciseCount: 1),
        },
      ).completeCloze(revealedAnswer);

      expect(flow.steps, hasLength(1));
      expect(flow.isFinished, isTrue);
    });

    test('discovery completes once Descubre to Úsala are behind', () {
      var flow = build(reviews: const []);
      for (var i = 0; i < 6; i++) {
        expect(flow.discoveryCompletedFor('n0'), isFalse);
        flow = flow.current!.isCloze
            ? flow.completeCloze(good)
            : flow.completeStep();
      }

      expect(flow.current, isA<FinalCheckStep>());
      expect(flow.discoveryCompletedFor('n0'), isTrue);
    });

    test('no sentence of a word repeats until all three are used', () {
      final seen = <String>[];
      var attempts = <ExerciseAttempt>[];
      // Day 0 introduces the word, then two reviews on later days.
      var flow = SessionFlow.build(
        reviewWordIds: const [],
        newWordIds: const ['n0'],
        words: words,
        progress: const {},
        attempts: attempts,
        today: day(1),
      );
      seen.addAll([for (final step in flow.steps) ?step.exerciseId]);
      attempts = [
        for (final (index, id) in seen.indexed)
          ExerciseAttempt(
            exerciseId: id,
            wordId: 'n0',
            attempts: 1,
            revealed: false,
            grade: Grade.good,
            localDate: day(1),
            createdAt: DateTime.utc(2026, 9, 1, index),
          ),
      ];

      for (var reviewDay = 2; reviewDay <= 3; reviewDay++) {
        flow = SessionFlow.build(
          reviewWordIds: const ['n0'],
          newWordIds: const [],
          words: words,
          progress: {
            'n0': buildProgress(wordId: 'n0', nextDueOn: day(reviewDay)),
          },
          attempts: attempts,
          today: day(reviewDay),
        );
        final id = flow.steps.first.exerciseId!;
        seen.add(id);
        attempts = [
          ...attempts,
          ExerciseAttempt(
            exerciseId: id,
            wordId: 'n0',
            attempts: 1,
            revealed: false,
            grade: Grade.good,
            localDate: day(reviewDay),
            createdAt: DateTime.utc(2026, 9, reviewDay),
          ),
        ];
      }

      // Elige, end-of-session check and the first review use all three
      // sentences before any of them comes back.
      expect(seen.take(3).toSet(), hasLength(3));
      expect(seen, hasLength(4));
    });
  });

  group('frustration cap', () {
    test('the third forced reveal switches the rest to reading mode', () {
      final flow = build(newWords: const ['n0', 'n1']);
      var next = flow.completeCloze(revealedAnswer);
      next = next.completeCloze(revealedAnswer);
      expect(next.seeding, isFalse);
      // Descubre and the first scene of n0, then its Elige is revealed.
      next = next.completeStep().completeStep();
      expect(next.current, isA<PracticeClozeStep>());
      next = next.completeCloze(revealedAnswer);

      expect(next.seeding, isTrue);
      expect(next.guard.isTriggered, isTrue);
      // n1's acquisition run had not started: postponed. Re-queues are
      // cancelled, and n0 switches to reading.
      expect(next.steps.skip(next.index), const [
        SessionStep.seedingReading(wordId: 'n0'),
      ]);
      expect(next.postponedWordIds, ['n1']);
    });

    test('words without readings are dropped in reading mode', () {
      final flow = build(
        reviews: const ['r0', 'noread'],
        newWords: const [],
        progress: {...reviewProgress, 'noread': reviewed('noread')},
        attempts: [
          attempt('r1', 1, attempts: 3, revealed: true),
          attempt('r1', 2, attempts: 3, revealed: true),
        ],
      ).completeCloze(revealedAnswer);

      expect(flow.seeding, isTrue);
      expect(flow.isFinished, isTrue);
    });
  });
}
