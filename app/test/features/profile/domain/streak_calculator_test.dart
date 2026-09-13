import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/profile/domain/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';

void main() {
  // 2026-09-16 is a Wednesday; its ISO week runs Sep 14 (Mon) to Sep 20.
  final wednesday = day(16);

  Set<LocalDate> days(List<int> list) => {for (final d in list) day(d)};

  StreakSummary summarize(
    List<int> active, {
    List<int> repairs = const [],
    LocalDate? today,
  }) => StreakCalculator.summarize(
    activityDates: days(active),
    repairedDates: days(repairs),
    today: today ?? wednesday,
  );

  group('weekly consistency ("N de 7 días")', () {
    test('marks active days Monday to Sunday of the current week', () {
      final summary = summarize([12, 13, 14, 16]);

      expect(summary.weekDays, [true, false, true, false, false, false, false]);
      expect(summary.activeDaysThisWeek, 2);
    });

    test('a new week starts on Monday', () {
      final summary = summarize([13, 14], today: day(14));

      expect(summary.weekDays.first, isTrue);
      expect(summary.activeDaysThisWeek, 1);
    });

    test('Sunday closes the week', () {
      final summary = summarize([7, 9, 13], today: day(13));

      expect(summary.weekDays, [true, false, true, false, false, false, true]);
      expect(summary.activeDaysThisWeek, 3);
    });

    test('repaired days count as active', () {
      expect(summarize([14, 16], repairs: [15]).activeDaysThisWeek, 3);
    });
  });

  group('current streak', () {
    final cases = <(String, List<int> active, List<int> repairs, int streak)>[
      ('no activity', [], [], 0),
      ('only today', [16], [], 1),
      ('ending today', [13, 14, 15, 16], [], 4),
      ('ending yesterday while today is still open', [13, 14, 15], [], 3),
      ('broken two days ago', [12, 13, 14], [], 0),
      ('bridged by a repair', [13, 14, 16], [15], 4),
      ('any activity in the gap counts', [10, 11, 13, 14, 15, 16], [], 4),
    ];
    for (final (name, active, repairs, streak) in cases) {
      test('$name -> $streak', () {
        expect(summarize(active, repairs: repairs).currentStreak, streak);
      });
    }
  });

  group('free weekly repair', () {
    test('offers the missed day that reconnects the streak', () {
      final summary = summarize([13, 14, 16]);

      expect(summary.repairableDate, day(15));
      expect(summary.streakAfterRepair, 4);
    });

    test('offers yesterday before today has any activity', () {
      final summary = summarize([13, 14]);

      expect(summary.currentStreak, 0);
      expect(summary.repairableDate, day(15));
      expect(summary.streakAfterRepair, 3);
    });

    test('nothing to repair when the streak is intact', () {
      expect(summarize([15, 16]).repairableDate, isNull);
    });

    test('never repairs two missed days in a row', () {
      expect(summarize([12, 13, 16]).repairableDate, isNull);
    });

    test('only within the last 7 days', () {
      final today = day(20);
      // Gap on Sep 13 is 7 days back (allowed); Sep 12 is 8 days back.
      expect(
        summarize([
          12,
          14,
          15,
          16,
          17,
          18,
          19,
          20,
        ], today: today).repairableDate,
        day(13),
      );
      expect(
        summarize([
          11,
          13,
          14,
          15,
          16,
          17,
          18,
          19,
          20,
        ], today: today).repairableDate,
        isNull,
      );
    });

    test('one repair per ISO week of the repaired date', () {
      // Sep 15 is in the week of Sep 14; a repair on Sep 14 used it.
      final used = summarize([12, 13, 16], repairs: [14]);
      expect(used.repairableDate, isNull);
      expect(used.repairUsedThisWeek, isTrue);

      // A repair from the previous week does not block this week.
      final previous = summarize([10, 12, 13, 14, 16], repairs: [11]);
      expect(previous.repairableDate, day(15));
      expect(previous.repairUsedThisWeek, isFalse);
    });

    test('with no activity before the gap there is nothing to reconnect', () {
      expect(summarize([16]).repairableDate, isNull);
    });
  });

  test('active dates join attempts, completed sessions and repairs', () {
    expect(
      StreakCalculator.activeDates(
        attemptDates: [day(1), day(2)],
        completedSessionDates: [day(2), day(3)],
        repairedDates: [day(5)],
      ),
      {day(1), day(2), day(3), day(5)},
    );
  });
}
