import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/training/domain/retake_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = RetakePolicy();

  test('next available date is exactly 30 days after the last diagnosis', () {
    final last = LocalDate(2026, 1, 1);
    expect(policy.nextAvailableOn(last), LocalDate(2026, 1, 31));
  });

  test('unavailable before 30 days have elapsed', () {
    final last = LocalDate(2026, 1, 1);
    expect(
      policy.isAvailable(lastDiagnosedOn: last, today: LocalDate(2026, 1, 20)),
      isFalse,
    );
  });

  test('available exactly on day 30', () {
    final last = LocalDate(2026, 1, 1);
    expect(
      policy.isAvailable(lastDiagnosedOn: last, today: LocalDate(2026, 1, 31)),
      isTrue,
    );
  });
}
