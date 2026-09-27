import 'dart:math';

/// Generates a fresh id for a row a client must supply before insert (e.g.
/// `speaking_attempts.id`, design part-3 §5: client-suppliable so the
/// storage path `<uid>/<id>.<ext>` can be computed and uploaded without
/// waiting for the insert's response).
abstract interface class IdGenerator {
  String generate();
}

/// An RFC 4122 version-4 (random) UUID, with no external dependency.
final class UuidV4Generator implements IdGenerator {
  const new();

  @override
  String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    String hex(int start, int length) => bytes
        .sublist(start, start + length)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 2)}-${hex(6, 2)}-${hex(8, 2)}-${hex(10, 6)}';
  }

  static final _random = Random.secure();
}
