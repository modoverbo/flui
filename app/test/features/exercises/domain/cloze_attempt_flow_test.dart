import 'dart:math';

import 'package:flui/features/exercises/domain/cloze_attempt_flow.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  final exercise = buildExercise(
    wordId: 'w1',
    distractors: ['suspicaz', 'perspicuo'],
  );
  final correct = exercise.correctOption.id;
  final suspicaz = exercise.options[1].id;
  final perspicuo = exercise.options[2].id;

  ClozeAttemptFlow start() => ClozeAttemptFlow.start(exercise);

  group('ClozeAttemptFlow (learning-method §3)', () {
    test('starts with all three options enabled and no feedback', () {
      final flow = start();

      expect(flow.options, hasLength(3));
      expect(flow.options.every((o) => flow.isEnabled(o.id)), isTrue);
      expect(flow.feedback, isNull);
      expect(flow.resolution, isNull);
      expect(flow.wrongAnswers, 0);
    });

    test('correct on the first try is good', () {
      final flow = start().answer(correct);

      expect(flow.isResolved, isTrue);
      expect(flow.resolution!.attempts, 1);
      expect(flow.resolution!.revealed, isFalse);
      expect(flow.resolution!.grade, Grade.good);
      expect(flow.resolution!.whyNot, isEmpty);
    });

    test('first wrong answer: "Casi." with the general hint', () {
      final flow = start().answer(suspicaz);

      expect(flow.isResolved, isFalse);
      expect(flow.wrongAnswers, 1);
      expect(flow.isEnabled(suspicaz), isFalse);
      expect(flow.isEnabled(correct), isTrue);
      expect(flow.feedback!.kind, ClozeHintKind.general);
      expect(flow.feedback!.text, exercise.hintGeneral);
      expect(flow.feedback!.optionId, suspicaz);
    });

    test('correct on the second try is hard', () {
      final flow = start().answer(suspicaz).answer(correct);

      expect(flow.resolution!.attempts, 2);
      expect(flow.resolution!.grade, Grade.hard);
      expect(flow.feedback, isNull);
    });

    test('second wrong answer: the specific hint of that option', () {
      final flow = start().answer(suspicaz).answer(perspicuo);

      expect(flow.wrongAnswers, 2);
      expect(flow.feedback!.kind, ClozeHintKind.specific);
      expect(flow.feedback!.text, 'Pista de perspicuo');
      expect(flow.mustPickRemaining, isTrue);
      expect(flow.enabledOptionIds, {correct});
    });

    test('the forced third choice reveals with every why-not', () {
      final flow = start().answer(perspicuo).answer(suspicaz).answer(correct);

      expect(flow.resolution!.attempts, 3);
      expect(flow.resolution!.revealed, isTrue);
      expect(flow.resolution!.grade, Grade.again);
      expect(flow.resolution!.whyNot, [
        (option: 'suspicaz', reason: 'Por qué no suspicaz'),
        (option: 'perspicuo', reason: 'Por qué no perspicuo'),
      ]);
    });

    test('dismissing the feedback keeps the discarded options', () {
      final flow = start().answer(suspicaz).dismissFeedback();

      expect(flow.feedback, isNull);
      expect(flow.isEnabled(suspicaz), isFalse);
    });

    test('rejects disabled options and answers after resolution', () {
      final wrong = start().answer(suspicaz);
      expect(() => wrong.answer(suspicaz), throwsStateError);
      expect(() => start().answer(correct).answer(correct), throwsStateError);
      expect(() => start().answer('unknown'), throwsStateError);
    });

    test('shuffles options deterministically with a seeded random', () {
      final a = ClozeAttemptFlow.start(exercise, random: Random(7));
      final b = ClozeAttemptFlow.start(exercise, random: Random(7));

      expect(
        a.options.map((o) => o.id).toList(),
        b.options.map((o) => o.id).toList(),
      );
      expect(a.options.map((o) => o.id).toSet(), {
        correct,
        suspicaz,
        perspicuo,
      });
    });

    test('keeps the stored order without a random', () {
      expect(start().options.map((o) => o.id).toList(), [
        correct,
        suspicaz,
        perspicuo,
      ]);
    });
  });
}
