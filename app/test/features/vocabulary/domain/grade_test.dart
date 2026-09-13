import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Grade.fromOutcome (learning-method §2)', () {
    final cases = <(int attempts, bool revealed, Grade expected)>[
      (1, false, Grade.good),
      (2, false, Grade.hard),
      (3, true, Grade.again),
      (3, false, Grade.again),
    ];
    for (final (attempts, revealed, expected) in cases) {
      test('attempts $attempts, revealed $revealed -> $expected', () {
        expect(
          Grade.fromOutcome(attempts: attempts, revealed: revealed),
          expected,
        );
      });
    }
  });
}
