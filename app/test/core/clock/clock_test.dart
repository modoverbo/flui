import 'package:flui/core/clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today() strips the time and keeps the local calendar date', () {
    final clock = FixedClock(DateTime(2026, 9, 13, 23, 59, 30));

    expect(clock.today(), DateTime(2026, 9, 13));
  });

  test('FixedClock can be advanced for deterministic tests', () {
    final clock = FixedClock(DateTime(2026, 9, 13, 8))
      ..advance(const Duration(hours: 17));

    expect(clock.now(), DateTime(2026, 9, 14, 1));
    expect(clock.today(), DateTime(2026, 9, 14));
  });

  test('SystemClock returns the current time', () {
    const clock = SystemClock();
    final before = DateTime.now();

    final now = clock.now();

    expect(now.isBefore(before), isFalse);
  });
}
