import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/daily_session.dart';

/// Minutes offered on "¿Cuánto tiempo tienes hoy?".
enum TimeBudget {
  five(5),
  ten(10),
  twenty(20),
  thirty(30);

  new(this.minutes);

  final int minutes;

  static const TimeBudget fallback = TimeBudget.ten;

  static TimeBudget? tryFromMinutes(int minutes) {
    for (final budget in values) {
      if (budget.minutes == minutes) return budget;
    }
    return null;
  }

  /// The budget to preselect: today's choice when there is one, else the
  /// latest earlier choice ("yesterday's choice", also when yesterday was
  /// skipped), else [fallback].
  static TimeBudget preselected({
    required LocalDate today,
    DailySession? previous,
  }) {
    if (previous == null || previous.localDate.isAfter(today)) return fallback;
    return tryFromMinutes(previous.minutes) ?? fallback;
  }
}
