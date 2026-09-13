/// How well a cloze was answered (`exercise_attempts.grade`).
enum Grade {
  /// Correct on the first try.
  good,

  /// Correct on the second try.
  hard,

  /// Two wrong answers, then the remaining option was forced.
  again;

  /// Grade of a resolved cloze (docs/learning-method.md §2).
  factory fromOutcome({required int attempts, required bool revealed}) {
    if (revealed || attempts >= 3) return Grade.again;
    return attempts <= 1 ? Grade.good : Grade.hard;
  }
}
