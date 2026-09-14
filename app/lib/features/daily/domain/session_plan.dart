import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_plan.freezed.dart';

/// Why a day has nothing planned. The three cases need different words and
/// different ways out: telling everyone to pick 10 minutes is only true for
/// the first one.
enum EmptyPlanReason {
  /// Five minutes buys no new word, and nothing is due. There are words left
  /// to learn, so a bigger budget fixes the day.
  budgetTooSmall,

  /// Every published word is already in the repertoire and nothing is due.
  /// A bigger budget changes nothing; only new content or a free run does.
  noCandidatesLeft,

  /// Words are left but each one is still too close to something learned in
  /// the last few days (docs/learning-method.md §7), and nothing is due.
  /// Distance is the point, so the honest answer is to come back.
  allReviewsDone,
}

/// Why today's new word does not come from the theme the user chose.
///
/// The exhaustion cascade, in order. A chosen theme never produces an empty
/// day and never produces a silent substitution: whichever step answers, the
/// user is told which one it was.
enum ThemeFallback {
  /// (a) The theme has no new word left, but the user already owns words of
  /// it: today recombines those instead of introducing anything.
  themedPractice,

  /// (b) The nearest theme by shared-word overlap lends a word.
  neighbourTheme,

  /// (c) Nothing adjacent is left either, so the next catalog word comes in.
  globalCatalog,
}

/// Output of the SessionPlanner for one day.
@freezed
abstract class SessionPlan with _$SessionPlan {
  const factory({
    required int budgetMinutes,

    /// Reviews in session order: warm-up items first, then the rest.
    ///
    /// Always the global due queue at its computed due dates, whatever theme
    /// was chosen. Reordering a schedule around a filter is exactly what Anki
    /// warns filtered decks do to a collection, and Bjork's desirable
    /// difficulties are the reason the spacing is worth protecting.
    required List<String> reviewWordIds,
    required List<String> newWordIds,

    /// "Hoy toca afianzar": reviews take more than half of the budget.
    required bool afianzar,

    /// How many of the first [reviewWordIds] are warm-up items.
    @Default(0) int warmUpCount,

    /// The theme chosen for the day, `null` for the global pool.
    String? themeId,

    /// Words already in `practica` that today recombines because the theme
    /// has no new word left. They never touch the review ladder: this is
    /// extra practice, not a review moved forward.
    @Default(<String>[]) List<String> recombinationWordIds,

    /// Set when the new word did not come from [themeId].
    ThemeFallback? themeFallback,

    /// The theme the substituted word does come from, when it has one, so the
    /// copy can name it instead of apologising vaguely.
    String? fallbackThemeId,

    /// Set only when the plan is empty.
    EmptyPlanReason? emptyReason,
  }) = _SessionPlan;

  const new _();

  bool get isEmpty =>
      reviewWordIds.isEmpty &&
      newWordIds.isEmpty &&
      recombinationWordIds.isEmpty;
}
