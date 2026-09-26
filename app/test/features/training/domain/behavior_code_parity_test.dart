import 'dart:convert';
import 'dart:io';

import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flutter_test/flutter_test.dart';

// Read-only: `behavior_codes.json` is the single wire-format source of
// truth (design §9, U9a.5/U11.3's LLM allow-list, U9a.7's content/ parity).
// This test only proves the app's closed catalog matches it.
void main() {
  test('BehaviorCode.wireCode matches behavior_codes.json exactly', () {
    final file = File(
      '../supabase/functions/speech-analyze/behavior_codes.json',
    );
    expect(
      file.existsSync(),
      isTrue,
      reason: 'behavior_codes.json must exist as the wire catalog',
    );

    final wire = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    final wireCodes = [
      for (final entry in wire) (entry as Map<String, dynamic>)['wireCode'],
    ];

    expect(wireCodes, BehaviorCode.values.map((c) => c.wireCode).toList());
  });
}
