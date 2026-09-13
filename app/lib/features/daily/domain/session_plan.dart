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

/// Output of the SessionPlanner for one day.
@freezed
abstract class SessionPlan with _$SessionPlan {
  const factory({
    required int budgetMinutes,

    /// Reviews in session order: warm-up items first, then the rest.
    required List<String> reviewWordIds,
    required List<String> newWordIds,

    /// "Hoy toca afianzar": reviews take more than half of the budget.
    required bool afianzar,

    /// How many of the first [reviewWordIds] are warm-up items.
    @Default(0) int warmUpCount,

    /// Set only when the plan is empty.
    EmptyPlanReason? emptyReason,
  }) = _SessionPlan;

  const new _();

  bool get isEmpty => reviewWordIds.isEmpty && newWordIds.isEmpty;
}
