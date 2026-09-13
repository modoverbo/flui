import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/session_planner.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/profile/domain/progress_stats.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
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
    required this.activeDaysThisWeek,
    this.precisionPercent,
  });

  final String? name;
  final DailySession? session;
  final List<Word> newWords;
  final int reviewCount;

  /// Something happened today (an answer or a word introduced).
  final bool started;
  final int ownedWords;
  final int activeDaysThisWeek;
  final int? precisionPercent;

  bool get completed => session?.isCompleted ?? false;

  bool get emptyPlan => session?.isEmpty ?? false;

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
  final name = ref.watch(authUserProvider.select((u) => u.value?.displayName));
  final today = ref.watch(clockProvider).localToday();
  final session = data.sessionOn(today);
  final stats = ProgressStats.compute(
    progress: data.progress,
    attempts: data.attempts,
    activeDates: data.activeDates,
  );
  final streak = StreakCalculator.summarize(
    activityDates: data.activityDates,
    repairedDates: data.repairs.toSet(),
    today: today,
  );
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
    activeDaysThisWeek: streak.activeDaysThisWeek,
    precisionPercent: stats.firstTryPrecisionPercent,
  );
}
