import 'dart:convert';
import 'dart:io';

import 'package:content/src/model/behavior_catalog.dart';
import 'package:test/test.dart';

// Read-only: `behavior_codes.json` is the single wire-format source of
// truth (design §9). This mirrors
// app/test/features/training/domain/behavior_code_parity_test.dart and only
// proves content/'s closed catalog matches it (three-way parity: app,
// content, speech-analyze).
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
