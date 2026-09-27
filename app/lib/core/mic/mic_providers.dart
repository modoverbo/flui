import 'dart:async';

import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mic_providers.g.dart';

@Riverpod(keepAlive: true)
MicTargetRegistry micTargetRegistry(Ref ref) {
  final registry = MicTargetRegistry();
  ref.onDispose(registry.dispose);
  return registry;
}

/// One [MicController] — and its one owned `HoldToRecord` — per signed-in
/// session (D23): rebuilds, disposing the previous controller, whenever
/// the signed-in user id changes, including to `null` on sign-out.
@Riverpod(keepAlive: true)
MicController? micController(Ref ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final controller = MicController(
    recorderFactory: ref.watch(speechRecorderFactoryProvider),
    registry: ref.watch(micTargetRegistryProvider),
    clock: ref.watch(clockProvider),
  );
  ref
    ..onDispose(() => unawaited(controller.dispose()))
    ..listen(accessGateProvider, (_, next) {
      controller.setAccessGranted(next == AccessGate.granted);
    }, fireImmediately: true);

  return controller;
}
