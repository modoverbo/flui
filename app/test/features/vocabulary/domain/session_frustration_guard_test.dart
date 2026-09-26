import 'package:flui/features/vocabulary/domain/exercises/session_frustration_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('triggers after three forced reveals in a session', () {
    var guard = const SessionFrustrationGuard();
    expect(guard.isTriggered, isFalse);

    guard = guard.recordForcedReveal().recordForcedReveal();
    expect(guard.forcedReveals, 2);
    expect(guard.isTriggered, isFalse);

    guard = guard.recordForcedReveal();
    expect(guard.isTriggered, isTrue);
  });

  test('can start from reveals already recorded today', () {
    expect(const SessionFrustrationGuard(forcedReveals: 3).isTriggered, isTrue);
  });
}
