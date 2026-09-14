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
import 'package:flui/features/exercises/presentation/providers/exercise_providers.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
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

    /// The user's theme tap; `null` shows the preselected theme.
    String? selectedThemeId,
    @Default(false) bool saving,
    Failure? failure,
  }) = _TimeBudgetState;
}

/// "¿Cuánto tiempo tienes hoy?" and "¿sobre qué tema?": plans the day and
/// saves `daily_sessions`.
///
/// The two answers are symmetric. Changing the theme recomputes the plan
/// exactly like changing the minutes does, and neither is locked in: there is
/// no minimum streak on a theme, so tomorrow can be a different one for free.
@riverpod
class TimeBudgetController extends _$TimeBudgetController {
  @override
  TimeBudgetState build() => const TimeBudgetState();

  void select(TimeBudget budget) =>
      state = state.copyWith(selected: budget, failure: null);

  void selectTheme(String themeId) =>
      state = state.copyWith(selectedThemeId: themeId, failure: null);

  /// "Sorpréndeme": any offered theme other than the one already showing.
  /// Deliberately not the "best" one — the point is to widen the catalog, and
  /// a recommendation the user did not ask for is not a surprise.
  Future<String?> surpriseTheme(String? current) async {
    final offered = await ref.readFuture(offeredThemesProvider.future);
    if (offered.isEmpty) return null;
    final pool = [
      for (final theme in offered)
        if (theme.id != current) theme,
    ];
    if (pool.isEmpty) return null;
    final random = ref.read(shuffleRandomProvider);
    final picked = pool[random == null ? 0 : random.nextInt(pool.length)];
    selectTheme(picked.id);
    return picked.id;
  }

  /// Plans with [budget] and [themeId] and saves today's session (recomputing
  /// an existing one). Returns whether it was saved.
  Future<bool> start(TimeBudget budget, {String? themeId}) async {
    if (state.saving) return false;
    state = state.copyWith(
      selected: budget,
      selectedThemeId: themeId,
      saving: true,
      failure: null,
    );
    try {
      final userId = (await ref.readFuture(authUserProvider.future))?.id;
      if (userId == null) throw notSignedInFailure;
      final catalog = await ref.readFuture(catalogProvider.future);
      final themes = await ref.readFuture(themesProvider.future);
      final data = await ref.readFuture(
        learningDataControllerProvider(userId).future,
      );
      final today = ref.read(clockProvider).localToday();
      final inputs = SessionPlanInputs.derive(
        catalog: catalog,
        progress: data.progress,
        today: today,
        themes: themes,
        themeId: themeId,
      );
      final plan = SessionPlanner.plan(
        budgetMinutes: budget.minutes,
        today: today,
        dueReviews: inputs.dueReviews,
        candidates: inputs.candidates,
        recentIntroductions: inputs.recentIntroductions,
        themeId: themeId,
        practiceWords: inputs.practiceWords,
        neighbourThemeIds: inputs.neighbourThemeIds,
      );
      final result = await ref
          .read(learningDataControllerProvider(userId).notifier)
          .saveSession(
            DailySession(
              localDate: today,
              minutes: budget.minutes,
              plannedWordIds: plan.newWordIds,
              reviewWordIds: plan.reviewWordIds,
              themeId: themeId,
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
