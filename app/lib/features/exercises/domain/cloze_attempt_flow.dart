import 'dart:math';

import 'package:flui/features/exercises/domain/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:meta/meta.dart';

enum ClozeHintKind {
  /// `exercises.hint_general`, after the first wrong answer.
  general,

  /// `exercise_options.hint_specific` of the chosen option, after the second.
  specific,
}

/// "Casi." feedback after a wrong answer. Never reveals the answer.
@immutable
final class ClozeHint {
  const new({required this.kind, required this.text, required this.optionId});

  final ClozeHintKind kind;
  final String text;

  /// The wrong option that was chosen.
  final String optionId;
}

/// How a cloze ended.
@immutable
final class ClozeResolution {
  const new({
    required this.attempts,
    required this.revealed,
    required this.grade,
    required this.explanation,
    required this.whyNot,
  });

  final int attempts;
  final bool revealed;
  final Grade grade;
  final String explanation;

  /// Why each distractor fails. Only filled on a forced reveal.
  final List<({String option, String reason})> whyNot;

  bool get firstTry => attempts == 1 && !revealed;
}

/// "Pista, no respuesta" (docs/learning-method.md §3).
///
/// 1. Wrong answer #1: "Casi." + general hint; the option is disabled.
/// 2. Wrong answer #2: "Casi." + the chosen option's specific hint.
/// 3. Only the correct option remains; tapping it resolves as a forced
///    reveal (`attempts = 3`, `revealed = true`, `again`).
@immutable
final class ClozeAttemptFlow {
  const new _({
    required this.exercise,
    required this.options,
    required this.discardedOptionIds,
    this.feedback,
    this.resolution,
  });

  /// Starts a cloze. Options are shuffled with [random] when given, so tests
  /// pass a seeded `Random` for a stable order.
  factory start(ClozeExercise exercise, {Random? random}) {
    final options = [...exercise.options];
    if (random != null) options.shuffle(random);
    return ClozeAttemptFlow._(
      exercise: exercise,
      options: List.unmodifiable(options),
      discardedOptionIds: const {},
    );
  }

  /// Wrong answers before the third choice is forced.
  static const maxWrongAnswers = 2;

  final ClozeExercise exercise;

  /// Options in display order.
  final List<ExerciseOption> options;
  final Set<String> discardedOptionIds;
  final ClozeHint? feedback;
  final ClozeResolution? resolution;

  bool get isResolved => resolution != null;

  int get wrongAnswers => discardedOptionIds.length;

  /// After two wrong answers only the correct option can be chosen.
  bool get mustPickRemaining => !isResolved && wrongAnswers >= maxWrongAnswers;

  bool isEnabled(String optionId) =>
      !isResolved && !discardedOptionIds.contains(optionId);

  Set<String> get enabledOptionIds => {
    for (final option in options)
      if (isEnabled(option.id)) option.id,
  };

  ClozeAttemptFlow answer(String optionId) {
    final option = options.where((o) => o.id == optionId).firstOrNull;
    if (option == null || !isEnabled(optionId)) {
      throw StateError('Option $optionId cannot be chosen now.');
    }

    if (option.isCorrect) {
      final attempts = wrongAnswers + 1;
      final revealed = wrongAnswers >= maxWrongAnswers;
      return ClozeAttemptFlow._(
        exercise: exercise,
        options: options,
        discardedOptionIds: discardedOptionIds,
        resolution: ClozeResolution(
          attempts: attempts,
          revealed: revealed,
          grade: Grade.fromOutcome(attempts: attempts, revealed: revealed),
          explanation: exercise.explanation,
          whyNot: revealed
              ? [
                  for (final distractor in exercise.distractors)
                    (option: distractor.text, reason: distractor.whyNot ?? ''),
                ]
              : const [],
        ),
      );
    }

    final hint = wrongAnswers == 0
        ? ClozeHint(
            kind: ClozeHintKind.general,
            text: exercise.hintGeneral,
            optionId: optionId,
          )
        : ClozeHint(
            kind: ClozeHintKind.specific,
            text: option.hintSpecific ?? exercise.hintGeneral,
            optionId: optionId,
          );
    return ClozeAttemptFlow._(
      exercise: exercise,
      options: options,
      discardedOptionIds: {...discardedOptionIds, optionId},
      feedback: hint,
    );
  }

  /// "Intentar de nuevo": hides the hint, keeps wrong options disabled.
  ClozeAttemptFlow dismissFeedback() => ClozeAttemptFlow._(
    exercise: exercise,
    options: options,
    discardedOptionIds: discardedOptionIds,
    resolution: resolution,
  );
}
