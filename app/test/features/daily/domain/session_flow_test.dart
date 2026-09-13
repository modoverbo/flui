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
  }) => SessionFlow.build(
    reviewWordIds: reviews,
    newWordIds: newWords,
    words: catalog ?? words,
    progress: progress ?? reviewProgress,
    attempts: attempts,
    today: today,
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
    test('reviews, then the discovery flow, then the end-of-session check', () {
      final flow = build();

      expect(flow.steps, const [
        SessionStep.reviewCloze(wordId: 'r0', exerciseId: 'r0-e1'),
        SessionStep.reviewCloze(wordId: 'r1', exerciseId: 'r1-e1'),
        SessionStep.discover(wordId: 'n0'),
        SessionStep.readings(wordId: 'n0'),
        SessionStep.practiceCloze(wordId: 'n0', exerciseId: 'n0-e1'),
        SessionStep.formRecall(wordId: 'n0', isReview: false),
        SessionStep.production(wordId: 'n0', isReview: false),
        SessionStep.finalCheck(wordId: 'n0', exerciseId: 'n0-e2'),
      ]);
      expect(flow.index, 0);
      expect(flow.current, flow.steps.first);
      expect(flow.isFinished, isFalse);
      expect(flow.seeding, isFalse);
    });

    test('final checks come after every new word', () {
      final flow = build(reviews: const [], newWords: const ['n0', 'n1']);

      expect(flow.steps.whereType<FinalCheckStep>().map((s) => s.wordId), [
        'n0',
        'n1',
      ]);
      expect(flow.steps.indexOf(const SessionStep.discover(wordId: 'n1')), 5);
      expect(flow.steps[10], isA<FinalCheckStep>());
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

    test('a new word introduced today without answers restarts discovery', () {
      final flow = build(
        reviews: const [],
        progress: {'n0': WordProgress.introduced(wordId: 'n0', today: today)},
      );

      expect(flow.current, const SessionStep.discover(wordId: 'n0'));
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
      expect(flow.total, 6);
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
      expect(flow.total, 8);
    });

    test('a first-try cloze does not re-queue', () {
      final flow = build().completeCloze(good);

      expect(flow.steps, hasLength(8));
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
      for (var i = 0; i < 5; i++) {
        expect(flow.discoveryCompletedFor('n0'), isFalse);
        flow = flow.current!.isCloze
            ? flow.completeCloze(good)
            : flow.completeStep();
      }

      expect(flow.current, isA<FinalCheckStep>());
      expect(flow.discoveryCompletedFor('n0'), isTrue);
    });
  });

  group('frustration cap', () {
    test('the third forced reveal switches the rest to reading mode', () {
      final flow = build(newWords: const ['n0', 'n1']);
      var next = flow.completeCloze(revealedAnswer);
      next = next.completeCloze(revealedAnswer);
      expect(next.seeding, isFalse);
      // Descubre and Mira of n0, then its Elige is revealed.
      next = next.completeStep().completeStep().completeCloze(revealedAnswer);

      expect(next.seeding, isTrue);
      expect(next.guard.isTriggered, isTrue);
      // n1 was not started: postponed. Re-queues are cancelled. n0 (started)
      // and the pending words switch to reading.
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
