import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/riverpod/ref_futures.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'time_budget_controller.freezed.dart';
part 'time_budget_controller.g.dart';

/// Today's choice if made, else the latest earlier choice, else 10 minutes.
@riverpod
Future<TimeBudget> preselectedBudget(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final today = ref.watch(clockProvider).localToday();
  return TimeBudget.preselected(
    today: today,
    previous: data.latestSessionUntil(today),
  );
}

@freezed
abstract class TimeBudgetState with _$TimeBudgetState {
  const factory({
    /// The user's tap; `null` shows the preselected budget.
    TimeBudget? selected,
    @Default(false) bool saving,
    Failure? failure,
  }) = _TimeBudgetState;
}

/// "¿Cuánto tiempo tienes hoy?": plans the day and saves `daily_sessions`.
@riverpod
class TimeBudgetController extends _$TimeBudgetController {
  @override
  TimeBudgetState build() => const TimeBudgetState();

  void select(TimeBudget budget) =>
      state = state.copyWith(selected: budget, failure: null);

  /// Plans with [budget] and saves today's session (recomputing an existing
  /// one). Returns whether it was saved.
  Future<bool> start(TimeBudget budget) async {
    if (state.saving) return false;
    state = state.copyWith(selected: budget, saving: true, failure: null);
    try {
      final userId = (await ref.readFuture(authUserProvider.future))?.id;
      if (userId == null) throw notSignedInFailure;
      final catalog = await ref.readFuture(catalogProvider.future);
      final data = await ref.readFuture(
        learningDataControllerProvider(userId).future,
      );
      final today = ref.read(clockProvider).localToday();
      final inputs = SessionPlanInputs.derive(
        catalog: catalog,
        progress: data.progress,
        today: today,
      );
      final plan = SessionPlanner.plan(
        budgetMinutes: budget.minutes,
        today: today,
        dueReviews: inputs.dueReviews,
        candidates: inputs.candidates,
        recentIntroductions: inputs.recentIntroductions,
      );
      final result = await ref
          .read(learningDataControllerProvider(userId).notifier)
          .saveSession(
            DailySession(
              localDate: today,
              minutes: budget.minutes,
              plannedWordIds: plan.newWordIds,
              reviewWordIds: plan.reviewWordIds,
            ),
          );
      if (!ref.mounted) return result.isOk;
      state = state.copyWith(saving: false, failure: result.failureOrNull);
      return result.isOk;
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(saving: false, failure: failure);
      return false;
    }
  }
}
