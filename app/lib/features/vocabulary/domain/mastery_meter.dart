import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';

/// The five visible rungs between meeting a word and owning it.
///
/// The three states (`nueva`, `practica`, `tuya`) are correct but coarse: a
/// user can work for two weeks and still read "0 palabras tuyas". These
/// rungs are the same criteria (docs/learning-method.md §5) shown one by one,
/// so effort is visible long before the gate opens.
enum MasteryStep {
  /// The word was introduced: Descubre is behind.
  discovered,

  /// It left `nueva`: an unaided answer in a sentence not seen that session.
  practiced,

  /// `form_recall_done`: the user typed it from memory.
  recall,

  /// `production_done`: the user wrote their own sentence with it.
  production,

  /// `tuya`: every criterion holds.
  owned,
}

/// Which rungs one word has reached.
abstract final class MasteryMeter {
  static const total = 5;

  static Set<MasteryStep> reached(WordProgress progress) => {
    MasteryStep.discovered,
    if (progress.state != WordState.nueva) MasteryStep.practiced,
    if (progress.formRecallDone) MasteryStep.recall,
    if (progress.productionDone) MasteryStep.production,
    if (progress.state == WordState.tuya) MasteryStep.owned,
  };

  static int countFor(WordProgress progress) => reached(progress).length;

  /// The next rung to aim for, `null` once the word is owned.
  static MasteryStep? nextFor(WordProgress progress) {
    final done = reached(progress);
    for (final step in MasteryStep.values) {
      if (!done.contains(step)) return step;
    }
    return null;
  }
}
