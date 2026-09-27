import 'package:flui/core/id/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UuidV4Generator', () {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('generates a well-formed version-4 uuid', () {
      const generator = UuidV4Generator();

      final id = generator.generate();

      expect(id, matches(uuidPattern));
    });

    test('generates a fresh id on every call', () {
      const generator = UuidV4Generator();

      final ids = {for (var i = 0; i < 50; i++) generator.generate()};

      expect(ids, hasLength(50));
    });
  });
}
