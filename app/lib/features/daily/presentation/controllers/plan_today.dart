import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/riverpod/ref_futures.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/training_planner.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Days of history `TrainingPlanner.planDay` considers for its focus-shift/
/// rotation signal (design part-3 §7).
const _recentAttemptsWindowDays = 14;

/// A single fixed difficulty for every published challenge pick (U15a):
/// no unit has wired a difficulty-progression signal into HOY yet, and
/// `training_lab_page.dart`'s own ENTRENAR mode cards do not pass one to
/// `TrainingPlanner` at all. Documented deviation, see apply-progress.
const _flatDifficulty = 1;

/// Plans and saves today's `daily_sessions` row (design part-3 §5, U15a):
/// the word-review plan (`SessionPlanner`, unchanged — composed, not
/// rewritten) plus, while `speakingGymEnabledProvider` is on, the speaking
/// goal (`TrainingPlanner.planDay`) woven into the SAME row's
/// `focus_area`/`challenge_id`/`woven_word_ids` columns.
///
/// Extracted from `TimeBudgetController.start` so both the existing
/// "¿Cuánto tiempo tienes hoy?" flow and HOY's new budget-free chips/mic
/// entry point (`TodayStartTarget`) share one persistence path. Flag off,
/// this is byte-identical to `TimeBudgetController.start`'s prior body —
/// no training fields are ever computed or written.
final class PlanToday {
  const new(this._ref);

  final Ref _ref;

  /// Saves today's plan at [budget]/[themeId] and returns the persisted
  /// session. Recomputes on every call — a deliberate re-plan (changing
  /// the duration or the theme) replans exactly like the pre-existing
  /// word-plan behavior always has; a passive page reload never calls
  /// this, so an already-persisted training goal is never re-rolled.
  Future<Result<DailySession>> run({
    required TimeBudget budget,
    String? themeId,
  }) async {
    final userId = (await _ref.readFuture(authUserProvider.future))?.id;
    if (userId == null) return const Result.err(notSignedInFailure);

    try {
      final catalog = await _ref.readFuture(catalogProvider.future);
      final themes = await _ref.readFuture(themesProvider.future);
      final data = await _ref.readFuture(
        learningDataControllerProvider(userId).future,
      );
      final today = _ref.read(clockProvider).localToday();
      final inputs = SessionPlanInputs.derive(
        catalog: catalog,
        progress: data.progress,
        today: today,
        themes: themes,
        themeId: themeId,
      );
      final wordPlan = SessionPlanner.plan(
        budgetMinutes: budget.minutes,
        today: today,
        dueReviews: inputs.dueReviews,
        candidates: inputs.candidates,
        recentIntroductions: inputs.recentIntroductions,
        themeId: themeId,
        practiceWords: inputs.practiceWords,
        neighbourThemeIds: inputs.neighbourThemeIds,
      );

      DailyTrainingPlan? trainingPlan;
      if (_ref.read(speakingGymEnabledProvider)) {
        trainingPlan = await _trainingPlan(
          userId: userId,
          today: today,
          budgetMinutes: budget.minutes,
          dueReviewWordIds: wordPlan.reviewWordIds,
        );
      }

      final session = DailySession(
        localDate: today,
        minutes: budget.minutes,
        plannedWordIds: wordPlan.newWordIds,
        reviewWordIds: wordPlan.reviewWordIds,
        themeId: themeId,
        focusArea: trainingPlan?.focusArea.name,
        challengeId: trainingPlan?.challenge?.id,
        wovenWordIds: trainingPlan?.wovenWordIds ?? const <String>[],
      );
      // Goes through the LearningData controller (not the repository
      // directly) so its in-memory cache updates optimistically the same
      // way `TimeBudgetController.start` always has — `todayOverview`
      // reads that cache, not the repository.
      final saved = await _ref
          .read(learningDataControllerProvider(userId).notifier)
          .saveSession(session);
      if (saved case Err(:final failure)) return Result.err(failure);
      return Result.ok(session);
    } on Failure catch (failure) {
      return Result.err(failure);
    }
  }

  /// A provisional (never persisted) preview of today's speaking goal at
  /// [budget] — HOY's chips card uses this before a session exists, so
  /// changing a chip re-plans in memory without writing anything (design
  /// part-3 §11 U15a: "changing a chip re-plans the provisional plan").
  /// `null` while signed out, without a diagnosis profile yet, or with the
  /// flag off.
  Future<DailyTrainingPlan?> previewTrainingGoal(TimeBudget budget) async {
    if (!_ref.read(speakingGymEnabledProvider)) return null;
    final userId = (await _ref.readFuture(authUserProvider.future))?.id;
    if (userId == null) return null;
    final catalog = await _ref.readFuture(catalogProvider.future);
    final data = await _ref.readFuture(
      learningDataControllerProvider(userId).future,
    );
    final today = _ref.read(clockProvider).localToday();
    final inputs = SessionPlanInputs.derive(
      catalog: catalog,
      progress: data.progress,
      today: today,
    );
    final wordPlan = SessionPlanner.plan(
      budgetMinutes: budget.minutes,
      today: today,
      dueReviews: inputs.dueReviews,
      candidates: inputs.candidates,
      recentIntroductions: inputs.recentIntroductions,
    );
    return await _trainingPlan(
      userId: userId,
      today: today,
      budgetMinutes: budget.minutes,
      dueReviewWordIds: wordPlan.reviewWordIds,
    );
  }

  Future<DailyTrainingPlan?> _trainingPlan({
    required String userId,
    required LocalDate today,
    required int budgetMinutes,
    required List<String> dueReviewWordIds,
  }) async {
    final profileRecord = await _ref.read(
      latestSkillProfileProvider(userId).future,
    );
    final profile = profileRecord?.profile;
    if (profile == null) return null;

    final publishedChallenges =
        (await _ref.read(challengeRepositoryProvider).fetchCatalog())
            .valueOrNull ??
        const <Challenge>[];
    final since = today.addDays(-_recentAttemptsWindowDays);
    final recentAttempts =
        (await _ref
                .read(speakingAttemptRepositoryProvider)
                .recentAttemptsSince(since))
            .valueOrNull ??
        const [];

    return const TrainingPlanner().planDay(
      profile: profile,
      recentAttempts: [
        for (final attempt in recentAttempts)
          TrainingAttemptSummary(
            date: attempt.localDate,
            context: attempt.context,
            challengeId: attempt.challengeId,
            opportunityCodes: [
              for (final observation in attempt.observations)
                if (observation.polarity == Polarity.opportunity)
                  observation.code,
            ],
          ),
      ],
      publishedChallenges: publishedChallenges,
      dueReviewWordIds: dueReviewWordIds,
      budgetMinutes: budgetMinutes,
      difficulty: _flatDifficulty,
      today: today,
    );
  }
}

final planTodayProvider = Provider<PlanToday>(PlanToday.new);
