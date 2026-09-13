import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDate', () {
    test('keeps the local calendar day of a DateTime', () {
      final date = LocalDate.fromDateTime(DateTime(2026, 9, 13, 23, 59));

      expect(date, LocalDate(2026, 9, 13));
      expect(date.year, 2026);
      expect(date.month, 9);
      expect(date.day, 13);
    });

    test('adds days across month and year boundaries', () {
      expect(LocalDate(2026, 9, 30).addDays(1), LocalDate(2026, 10, 1));
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
      expect(LocalDate(2028, 3, 1).addDays(-1), LocalDate(2028, 2, 29));
    });

    test('counts whole days between dates, ignoring daylight saving', () {
      expect(LocalDate(2026, 3, 1).daysUntil(LocalDate(2026, 4, 1)), 31);
      expect(LocalDate(2026, 9, 13).daysUntil(LocalDate(2026, 9, 6)), -7);
    });

    test('compares chronologically', () {
      final a = LocalDate(2026, 9, 12);
      final b = LocalDate(2026, 9, 13);

      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.compareTo(b), lessThan(0));
      expect(a.isBefore(a), isFalse);
      expect([b, a]..sort(), [a, b]);
    });

    test('knows the ISO weekday and the Monday of its week', () {
      // 2026-09-13 is a Sunday.
      final sunday = LocalDate(2026, 9, 13);

      expect(sunday.weekday, DateTime.sunday);
      expect(sunday.startOfIsoWeek, LocalDate(2026, 9, 7));
      expect(LocalDate(2026, 9, 7).startOfIsoWeek, LocalDate(2026, 9, 7));
      expect(LocalDate(2026, 9, 14).startOfIsoWeek, LocalDate(2026, 9, 14));
    });

    test('round-trips the yyyy-MM-dd format used by Postgres dates', () {
      expect(LocalDate(2026, 1, 5).toIso(), '2026-01-05');
      expect(LocalDate.parse('2026-09-13'), LocalDate(2026, 9, 13));
      expect(LocalDate(2026, 9, 13).toString(), '2026-09-13');
    });

    test('rejects malformed dates', () {
      expect(() => LocalDate.parse('13/09/2026'), throwsFormatException);
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
    });

    test('converts to a local midnight DateTime', () {
      expect(LocalDate(2026, 9, 13).toDateTime(), DateTime(2026, 9, 13));
    });

    test('the clock gives today as a local date', () {
      final clock = FixedClock(DateTime(2026, 9, 13, 8, 30));

      expect(clock.localToday(), LocalDate(2026, 9, 13));
    });
  });
}
