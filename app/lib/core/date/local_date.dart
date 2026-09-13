import 'package:flui/core/clock/clock.dart';
import 'package:meta/meta.dart';

/// A calendar date in the user's time zone, without a time of day.
///
/// Learning rules count whole days (review ladder, streaks, 7-day windows).
/// Doing that arithmetic on `DateTime` breaks around daylight saving changes,
/// so dates are stored as a day number in a UTC calendar.
@immutable
final class LocalDate implements Comparable<LocalDate> {
  factory(int year, int month, int day) {
    final utc = DateTime.utc(year, month, day);
    if (utc.year != year || utc.month != month || utc.day != day) {
      throw FormatException('Invalid date', '$year-$month-$day');
    }
    return LocalDate._(utc.millisecondsSinceEpoch ~/ _msPerDay);
  }

  /// The local calendar day of [dateTime].
  factory fromDateTime(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return LocalDate(local.year, local.month, local.day);
  }

  /// Parses `yyyy-MM-dd` (the JSON form of a Postgres `date`).
  factory parse(String value) {
    final match = _isoPattern.firstMatch(value.trim());
    if (match == null) throw FormatException('Invalid date', value);
    return LocalDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  const new _(this._epochDay);

  static const int _msPerDay = Duration.millisecondsPerDay;
  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Days since 1970-01-01.
  final int _epochDay;

  DateTime get _utc =>
      DateTime.fromMillisecondsSinceEpoch(_epochDay * _msPerDay, isUtc: true);

  int get year => _utc.year;

  int get month => _utc.month;

  int get day => _utc.day;

  /// ISO weekday: [DateTime.monday] (1) to [DateTime.sunday] (7).
  int get weekday => _utc.weekday;

  /// The Monday of this date's ISO week.
  LocalDate get startOfIsoWeek => addDays(1 - weekday);

  LocalDate addDays(int days) => LocalDate._(_epochDay + days);

  /// Whole days from this date to [other] (negative when [other] is earlier).
  int daysUntil(LocalDate other) => other._epochDay - _epochDay;

  bool isBefore(LocalDate other) => _epochDay < other._epochDay;

  bool isAfter(LocalDate other) => _epochDay > other._epochDay;

  /// Local midnight of this date.
  DateTime toDateTime() => DateTime(year, month, day);

  /// `yyyy-MM-dd`.
  String toIso() {
    final utc = _utc;
    final mm = utc.month.toString().padLeft(2, '0');
    final dd = utc.day.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-$mm-$dd';
  }

  @override
  int compareTo(LocalDate other) => _epochDay.compareTo(other._epochDay);

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other._epochDay == _epochDay;

  @override
  int get hashCode => _epochDay.hashCode;

  @override
  String toString() => toIso();
}

extension ClockLocalDate on Clock {
  /// Today's calendar date in the device's time zone.
  LocalDate localToday() => LocalDate.fromDateTime(now());
}
