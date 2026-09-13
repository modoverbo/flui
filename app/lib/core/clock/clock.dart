/// Source of the current time. Inject it instead of calling `DateTime.now()`
/// so date-based rules (local dates, trials, polling) stay testable.
abstract interface class Clock {
  DateTime now();
}

/// Waits for [duration]. Injected next to [Clock] so polling loops can run
/// instantly in tests.
typedef Sleep = Future<void> Function(Duration duration);

Future<void> realSleep(Duration duration) => Future<void>.delayed(duration);

extension ClockDates on Clock {
  /// Today's local calendar date (time set to midnight).
  DateTime today() {
    final current = now();
    return DateTime(current.year, current.month, current.day);
  }
}

final class SystemClock implements Clock {
  const new();

  @override
  DateTime now() => DateTime.now();
}

/// A clock that only moves when told to. Useful in tests and fakes.
final class FixedClock implements Clock {
  new(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}
