import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  group('TimeBudget', () {
    test('offers 5, 10, 20 and 30 minutes', () {
      expect(TimeBudget.values.map((b) => b.minutes), [5, 10, 20, 30]);
    });

    test('maps minutes back to a budget', () {
      expect(TimeBudget.tryFromMinutes(20), TimeBudget.twenty);
      expect(TimeBudget.tryFromMinutes(15), isNull);
    });

    test("preselects yesterday's choice", () {
      final yesterday = DailySession(localDate: day(12), minutes: 20);

      expect(
        TimeBudget.preselected(today: day(13), previous: yesterday),
        TimeBudget.twenty,
      );
    });

    test('preselects the latest earlier choice when yesterday was skipped', () {
      final lastWeek = DailySession(localDate: day(6), minutes: 30);

      expect(
        TimeBudget.preselected(today: day(13), previous: lastWeek),
        TimeBudget.thirty,
      );
    });

    test('keeps the choice already made today', () {
      final todays = DailySession(localDate: day(13), minutes: 5);

      expect(
        TimeBudget.preselected(today: day(13), previous: todays),
        TimeBudget.five,
      );
    });

    test('defaults to 10 minutes without a usable earlier choice', () {
      expect(TimeBudget.preselected(today: day(13)), TimeBudget.ten);
      expect(
        TimeBudget.preselected(
          today: day(13),
          previous: DailySession(localDate: day(12), minutes: 45),
        ),
        TimeBudget.ten,
      );
    });
  });
}
