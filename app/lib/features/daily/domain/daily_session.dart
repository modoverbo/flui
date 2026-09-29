import 'package:flui/core/date/local_date.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_session.freezed.dart';

/// The time budget of a local day and its plan (`daily_sessions` row).
@freezed
abstract class DailySession with _$DailySession {
  const factory({
    required LocalDate localDate,
    required int minutes,

    /// New words to introduce today, in order.
    @Default(<String>[]) List<String> plannedWordIds,

    /// Reviews for today, in order (warm-up first).
    @Default(<String>[]) List<String> reviewWordIds,

    /// The theme chosen for the day, `null` for the global pool. Changing it
    /// recomputes the plan exactly like [minutes] does.
    String? themeId,
    DateTime? completedAt,

    /// `TrainingPlanner.planDay`'s chosen `SkillArea` (wire value, e.g.
    /// `'thinking'`) for today's speaking goal, `null` before the planner
    /// has run (flag off, or a session saved before this field existed —
    /// design part-3 §5, U15a).
    String? focusArea,

    /// The challenge picked for today's first speaking round, `null` when
    /// the planner had nothing published to offer.
    String? challengeId,

    /// Up to 3 due review word ids woven into the speaking loop's transfer
    /// step (U15b weaves them; U15a only persists the planner's picks).
    @Default(<String>[]) List<String> wovenWordIds,
  }) = _DailySession;

  const new _();

  bool get isCompleted => completedAt != null;

  bool get isEmpty => plannedWordIds.isEmpty && reviewWordIds.isEmpty;

  /// Whether `TrainingPlanner.planDay` has already run for this session —
  /// its result is persisted once and never re-rolled on a plain reload.
  bool get hasTrainingPlan => challengeId != null || focusArea != null;
}
