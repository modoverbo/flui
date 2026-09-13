import 'package:flui/core/date/local_date.dart';
import 'package:meta/meta.dart';

/// Weekly consistency and streak for "Tu progreso".
@immutable
final class StreakSummary {
  const new({
    required this.weekDays,
    required this.currentStreak,
    required this.repairUsedThisWeek,
    this.repairableDate,
    this.streakAfterRepair,
  });

  /// Monday to Sunday of the current ISO week: `true` when active.
  final List<bool> weekDays;
  final int currentStreak;

  /// The missed day the free weekly repair can fill, if any.
  final LocalDate? repairableDate;

  /// The streak once [repairableDate] is repaired.
  final int? streakAfterRepair;

  /// A repaired date already falls in the current ISO week.
  final bool repairUsedThisWeek;

  int get activeDaysThisWeek => weekDays.where((active) => active).length;
}

/// Streak rules (docs/learning-method.md §6).
///
/// - Active day: an exercise attempt, a completed session or a repair.
/// - Week: ISO week, Monday to Sunday, in local dates.
/// - Streak: consecutive active days ending today, or yesterday while today
///   has no activity yet.
/// - Free repair: at most one per ISO week of the repaired date, for a missed
///   day within the last 7 days that reconnects the streak.
abstract final class StreakCalculator {
  static const repairWindowDays = 7;

  static Set<LocalDate> activeDates({
    required Iterable<LocalDate> attemptDates,
    required Iterable<LocalDate> completedSessionDates,
    required Iterable<LocalDate> repairedDates,
  }) => {...attemptDates, ...completedSessionDates, ...repairedDates};

  static StreakSummary summarize({
    required Set<LocalDate> activityDates,
    required Set<LocalDate> repairedDates,
    required LocalDate today,
  }) {
    final active = {...activityDates, ...repairedDates};
    final monday = today.startOfIsoWeek;
    final weekDays = [
      for (var i = 0; i < 7; i++) active.contains(monday.addDays(i)),
    ];

    final end = active.contains(today) ? today : today.addDays(-1);
    final streak = _runEndingAt(active, end);
    final gap = end.addDays(-streak);

    final withinWindow =
        gap.isBefore(today) && !gap.isBefore(today.addDays(-repairWindowDays));
    final reconnects = active.contains(gap.addDays(-1));
    final weekFree = !repairedDates.any(
      (date) => date.startOfIsoWeek == gap.startOfIsoWeek,
    );
    final canRepair = withinWindow && reconnects && weekFree;

    return StreakSummary(
      weekDays: weekDays,
      currentStreak: streak,
      repairUsedThisWeek: repairedDates.any(
        (date) => date.startOfIsoWeek == monday,
      ),
      repairableDate: canRepair ? gap : null,
      streakAfterRepair: canRepair ? _runEndingAt({...active, gap}, end) : null,
    );
  }

  static int _runEndingAt(Set<LocalDate> active, LocalDate end) {
    var count = 0;
    var cursor = end;
    while (active.contains(cursor)) {
      count++;
      cursor = cursor.addDays(-1);
    }
    return count;
  }
}
