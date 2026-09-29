import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/mastery_policy.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';

/// Client-side spoken-use detection and mastery update (design D15: "spoken
/// word use detected client-side by `WordForms.appearsIn(transcript)` +
/// `MasteryPolicy.review(good)`, no penalty"). Pure Dart, shared by HOY's
/// woven-word transfer step (U15b) and PALABRAS' spoken-use step (U17), per
/// detail-3's own "shared logic, reused by U17" note.
abstract final class SpokenWordUse {
  /// The subset of [targetWordIds] that [transcript] actually uses.
  ///
  /// Detection goes through [Word.forms] / `WordForms.appearsIn`, which is
  /// already accent/case-insensitive (`normalizeText`) and matches only a
  /// known form (lemma, family, known inflections) or a long-enough stem
  /// extension — never a bare substring. A target id missing from
  /// [wordsById] (never fetched, or removed from the catalog) counts as
  /// unused rather than throwing: when in doubt, it did not happen.
  static List<String> detect({
    required List<String> targetWordIds,
    required Map<String, Word> wordsById,
    required String transcript,
  }) => [
    for (final id in targetWordIds)
      if (wordsById[id]?.forms.appearsIn(transcript) ?? false) id,
  ];

  /// The mastery update for one word just detected as spoken: a `good`
  /// review (same ladder advance any other review gets) plus
  /// `productionDone` (the word was actively produced, not merely
  /// recalled) — but only when [progress] is actually due on [today].
  ///
  /// An off-schedule detection — the same word used twice in one session,
  /// or a second [detect] call re-checking an attempt whose save is being
  /// retried — must never double-advance the ladder. This mirrors
  /// `SessionController`'s own free-run rule ("grading a word that is not
  /// due would push its real review away and quietly break the ladder").
  /// Returns `null` when nothing should be written.
  static WordProgress? review(
    WordProgress progress, {
    required LocalDate today,
    required DateTime now,
  }) {
    if (!progress.isDueOn(today)) return null;
    return MasteryPolicy.evaluateTuya(
      MasteryPolicy.review(
        progress,
        grade: Grade.good,
        today: today,
        now: now,
      ).copyWith(productionDone: true),
    );
  }
}
