import 'package:freezed_annotation/freezed_annotation.dart';

part 'cloze_exercise.freezed.dart';

/// Why a distractor is plausible (`exercise_options.distractor_type`).
enum DistractorType { paronym, nearSynonym, register }

/// One of the three options of a cloze (`exercise_options` row).
@freezed
abstract class ExerciseOption with _$ExerciseOption {
  const factory({
    required String id,
    required String text,
    required bool isCorrect,
    required int position,
    DistractorType? distractorType,

    /// Why this distractor fails in the sentence (distractors only).
    String? whyNot,

    /// Nudge shown after a second wrong answer on this option.
    String? hintSpecific,
  }) = _ExerciseOption;
}

/// A fill-in-the-blank exercise (`exercises` row with its options).
@freezed
abstract class ClozeExercise with _$ClozeExercise {
  const factory({
    required String id,
    required String wordId,

    /// Contains exactly one [blankToken].
    required String sentence,
    required String hintGeneral,
    required String explanation,
    required int position,
    required List<ExerciseOption> options,
  }) = _ClozeExercise;

  const new _();

  static const blankToken = '{{blank}}';

  ExerciseOption get correctOption =>
      options.firstWhere((option) => option.isCorrect);

  List<ExerciseOption> get distractors => [
    for (final option in options)
      if (!option.isCorrect) option,
  ];

  /// The sentence around the blank.
  ({String before, String after}) get sentenceParts {
    final index = sentence.indexOf(blankToken);
    if (index < 0) return (before: sentence, after: '');
    return (
      before: sentence.substring(0, index),
      after: sentence.substring(index + blankToken.length),
    );
  }
}
