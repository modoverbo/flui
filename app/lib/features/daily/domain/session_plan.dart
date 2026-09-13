import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_plan.freezed.dart';

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
  }) = _SessionPlan;

  const new _();

  bool get isEmpty => reviewWordIds.isEmpty && newWordIds.isEmpty;
}
