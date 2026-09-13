import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// A test container with Riverpod's automatic retry disabled, so failures
/// surface immediately and no retry timers stay pending.
ProviderContainer createTestContainer({List<Override> overrides = const []}) {
  return ProviderContainer.test(overrides: overrides, retry: (_, _) => null);
}
