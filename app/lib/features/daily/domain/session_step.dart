import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_step.freezed.dart';

/// One screen of a session, in order (docs/learning-method.md §1).
@freezed
sealed class SessionStep with _$SessionStep {
  /// A due review: one cloze with a sentence not seen most recently.
  const factory reviewCloze({
    required String wordId,
    required String exerciseId,
  }) = ReviewClozeStep;

  /// Descubre + Entiende: the word detail.
  const factory discover({required String wordId}) = DiscoverStep;

  /// Mira: the readings carousel.
  const factory readings({required String wordId}) = ReadingsStep;

  /// Elige: the first cloze of a new word.
  const factory practiceCloze({
    required String wordId,
    required String exerciseId,
  }) = PracticeClozeStep;

  /// Úsala (1/2): typed recall. Also added to reviews while
  /// `form_recall_done` is false.
  const factory formRecall({required String wordId, required bool isReview}) =
      FormRecallStep;

  /// Úsala (2/2): the user's own sentence. Also added to reviews while
  /// `production_done` is false.
  const factory production({required String wordId, required bool isReview}) =
      ProductionStep;

  /// End-of-session check: a fresh cloze per new word.
  const factory finalCheck({
    required String wordId,
    required String exerciseId,
  }) = FinalCheckStep;

  /// A forced reveal re-queues the word once, with another exercise.
  const factory requeueCloze({
    required String wordId,
    required String exerciseId,
    required bool fromReview,
  }) = RequeueClozeStep;

  /// After the frustration cap: reading only ("Hoy estás sembrando").
  const factory seedingReading({required String wordId}) = SeedingReadingStep;
}

extension SessionStepExercise on SessionStep {
  /// The cloze exercise of this step, or `null` for non-cloze steps.
  String? get exerciseId => switch (this) {
    ReviewClozeStep(:final exerciseId) ||
    PracticeClozeStep(:final exerciseId) ||
    FinalCheckStep(:final exerciseId) ||
    RequeueClozeStep(:final exerciseId) => exerciseId,
    DiscoverStep() ||
    ReadingsStep() ||
    FormRecallStep() ||
    ProductionStep() ||
    SeedingReadingStep() => null,
  };

  bool get isCloze => exerciseId != null;
}
