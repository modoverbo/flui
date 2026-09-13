import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/core/riverpod/ref_futures.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/profile/domain/achievements.dart';
import 'package:flui/features/profile/domain/progress_stats.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress_overview.g.dart';

/// View model of "Tu progreso".
@immutable
final class ProgressOverview {
  const new({
    required this.streak,
    required this.stats,
    required this.achievements,
  });

  final StreakSummary streak;
  final ProgressStats stats;
  final List<Achievement> achievements;
}

@riverpod
Future<ProgressOverview> progressOverview(Ref ref) async {
  final data = await ref.watch(currentLearningDataProvider.future);
  final today = ref.watch(clockProvider).localToday();
  final stats = ProgressStats.compute(
    progress: data.progress,
    attempts: data.attempts,
    activeDates: data.activeDates,
  );
  return ProgressOverview(
    streak: StreakCalculator.summarize(
      activityDates: data.activityDates,
      repairedDates: data.repairs.toSet(),
      today: today,
    ),
    stats: stats,
    achievements: Achievements.compute(
      progress: data.progress,
      activeDays: stats.activeDays,
    ),
  );
}

/// The free weekly streak repair. State: `true` while saving.
@riverpod
class StreakRepairController extends _$StreakRepairController {
  @override
  bool build() => false;

  Future<Result<void>> repair(LocalDate date) async {
    if (state) return const Result.ok(null);
    state = true;
    final user = await ref.readFuture(authUserProvider.future);
    final result = user == null
        ? const Result<void>.err(notSignedInFailure)
        : await ref
              .read(learningDataControllerProvider(user.id).notifier)
              .repairDay(date);
    if (ref.mounted) state = false;
    return result;
  }
}
