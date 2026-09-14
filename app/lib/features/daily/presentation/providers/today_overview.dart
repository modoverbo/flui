import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_plan.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/daily/domain/theme_outcome.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/profile/domain/progress_stats.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/domain/theme_neighbours.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'today_overview.g.dart';

/// View model of "Hoy".
@immutable
final class TodayOverview {
  const new({
    required this.name,
    required this.session,
    required this.newWords,
    required this.reviewCount,
    required this.started,
    required this.ownedWords,
    required this.practiceWords,
    required this.activeDays,
    required this.activeDaysThisWeek,
    required this.weekDays,
    required this.streak,
    required this.dueCount,
    required this.canReviewFreely,
    this.emptyReason,
    this.theme,
    this.otherTheme,
    this.themeFallback,
    this.recombinationCount = 0,
    this.nextReviewOn,
    this.nextReviewCount = 0,
    this.precisionPercent,
  });

  final String? name;
  final DailySession? session;
  final List<Word> newWords;
  final int reviewCount;

  /// Something happened today (an answer or a word introduced).
  final bool started;
  final int ownedWords;

  /// Words met but not owned yet: the progress the mastery gate hides.
  final int practiceWords;
  final int activeDays;
  final int activeDaysThisWeek;

  /// Monday to Sunday of the current week: `true` when active.
  final List<bool> weekDays;

  /// Consecutive active days ending today (or yesterday, before today's run).
  final int streak;

  /// Reviews due today, whether or not today's plan covers them.
  final int dueCount;

  /// At least one word is available for a free run.
  final bool canReviewFreely;

  /// Why today has nothing planned; `null` when the plan is not empty.
  final EmptyPlanReason? emptyReason;

  /// The theme today was planned with, `null` for the global pool.
  final Theme? theme;

  /// The theme today's word actually came from, when it was not [theme].
  final Theme? otherTheme;

  /// Set when the new word did not come from [theme]; the copy says so.
  final ThemeFallback? themeFallback;

  /// Words of the theme the day recombines because it had no new word left.
  final int recombinationCount;

  /// The next day with reviews waiting, and how many land on it.
  final LocalDate? nextReviewOn;
  final int nextReviewCount;
  final int? precisionPercent;

  bool get completed => session?.isCompleted ?? false;

  /// A day with nothing to do. Themed recombination counts as something: the
  /// theme ran out of new words, not out of work.
  bool get emptyPlan => (session?.isEmpty ?? false) && recombinationCount == 0;

  /// The hero number is never a bare zero: before the first `tuya`, it shows
  /// the words in practice instead.
  bool get showsOwnedHero => ownedWords > 0;

  bool get afianzar {
    final session = this.session;
    return session != null &&
        SessionPlanner.isAfianzar(
          minutes: session.minutes,
          reviewCount: session.reviewWordIds.length,
        );
  }
}

@riverpod
Future<TodayOverview> todayOverview(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final words = await ref.watch(wordsByIdProvider.future);
  final allThemes = await ref.watch(themesProvider.future);
  final themesById = await ref.watch(themesByIdProvider.future);
  final name = ref.watch(authUserProvider.select((u) => u.value?.displayName));
  final today = ref.watch(clockProvider).localToday();
  final session = data.sessionOn(today);
  final theme = themesById[session?.themeId];
  final outcome = session == null
      ? ThemeOutcome.onTheme
      : ThemeOutcome.of(
          session: session,
          wordsById: words,
          practiceWords: [
            for (final row in data.progress)
              if (row.state == WordState.practica && words[row.wordId] != null)
                words[row.wordId]!,
          ],
          neighbourThemeIds: theme == null
              ? const []
              : ThemeNeighbours.nearestIds(
                  theme: theme,
                  themes: allThemes,
                  catalog: words.values.toList(),
                ),
        );
  final stats = ProgressStats.compute(
    progress: data.progress,
    attempts: data.attempts,
    activeDates: data.activeDates,
    today: today,
  );
  final streak = StreakCalculator.summarize(
    activityDates: data.activityDates,
    repairedDates: data.repairs.toSet(),
    today: today,
  );

  final known = [
    for (final row in data.progress)
      if (words.containsKey(row.wordId)) row,
  ];
  LocalDate? nextReviewOn;
  for (final row in known) {
    final due = row.nextDueOn;
    if (due == null || !due.isAfter(today)) continue;
    if (nextReviewOn == null || due.isBefore(nextReviewOn)) nextReviewOn = due;
  }

  return TodayOverview(
    name: (name == null || name.trim().isEmpty) ? null : name.trim(),
    session: session,
    newWords: [
      for (final id in session?.plannedWordIds ?? const <String>[]) ?words[id],
    ],
    reviewCount: session?.reviewWordIds.length ?? 0,
    started:
        data.attemptsOn(today).isNotEmpty ||
        data.progress.any((row) => row.introducedOn == today),
    ownedWords: stats.tuya,
    practiceWords: stats.inPractice,
    activeDays: stats.activeDays,
    activeDaysThisWeek: streak.activeDaysThisWeek,
    weekDays: streak.weekDays,
    streak: streak.currentStreak,
    dueCount: known.where((row) => row.isDueOn(today)).length,
    canReviewFreely: known.any((row) => row.state != WordState.nueva),
    emptyReason: session != null && session.isEmpty
        ? _emptyReasonFor(
            catalog: words.values.toList(),
            progress: data.progress,
            minutes: session.minutes,
            today: today,
          )
        : null,
    theme: theme,
    otherTheme: themesById[outcome.otherThemeId],
    themeFallback: outcome.fallback,
    recombinationCount: outcome.recombinationWordIds.length,
    nextReviewOn: nextReviewOn,
    nextReviewCount: nextReviewOn == null
        ? 0
        : known.where((row) => row.nextDueOn == nextReviewOn).length,
    precisionPercent: stats.firstTryPrecisionPercent,
  );
}

/// Re-plans today to learn *why* it is empty. `daily_sessions` stores the
/// plan, not the reason, and the reason is cheap to derive from live data.
EmptyPlanReason? _emptyReasonFor({
  required List<Word> catalog,
  required List<WordProgress> progress,
  required int minutes,
  required LocalDate today,
}) {
  final inputs = SessionPlanInputs.derive(
    catalog: catalog,
    progress: progress,
    today: today,
  );
  return SessionPlanner.plan(
    budgetMinutes: minutes,
    today: today,
    dueReviews: inputs.dueReviews,
    candidates: inputs.candidates,
    recentIntroductions: inputs.recentIntroductions,
  ).emptyReason;
}
