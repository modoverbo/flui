import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flui/core/mic/presentation/mic_layer_scope.dart';
import 'package:flui/core/mic/presentation/mic_target_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeMicTarget implements MicTarget {
  new({required this.prompt});

  @override
  final MicPrompt prompt;

  @override
  final Duration maxDuration = const Duration(seconds: 30);

  @override
  MicAvailability get availability => const MicReady();

  final _c = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _c.stream;

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async => const MicAccepted();
}

void main() {
  testWidgets(
    'registers the target in initState against the registry from context, '
    'disposes it on unmount',
    (tester) async {
      final registry = MicTargetRegistry();
      final target = _FakeMicTarget(prompt: const MicPrompt(actionLabel: 'A'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [micTargetRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            home: MicTargetScope(target: target, child: const SizedBox()),
          ),
        ),
      );

      final (resolved, _) = registry.resolve();
      expect(resolved, same(target));

      await tester.pumpWidget(const SizedBox());
      final (afterUnmount, _) = registry.resolve();
      expect(afterUnmount, isNot(same(target)));
    },
  );

  testWidgets('calls update() on the registration when the target changes', (
    tester,
  ) async {
    final registry = MicTargetRegistry();
    final first = _FakeMicTarget(prompt: const MicPrompt(actionLabel: 'A'));
    final second = _FakeMicTarget(prompt: const MicPrompt(actionLabel: 'B'));

    Widget build(MicTarget target) => ProviderScope(
      overrides: [micTargetRegistryProvider.overrideWithValue(registry)],
      child: MaterialApp(
        home: MicTargetScope(target: target, child: const SizedBox()),
      ),
    );

    await tester.pumpWidget(build(first));
    var (resolved, _) = registry.resolve();
    expect(resolved, same(first));

    await tester.pumpWidget(build(second));
    (resolved, _) = registry.resolve();
    expect(resolved, same(second));
  });

  testWidgets(
    'without a MicLayerScope ancestor, registers on the root layer (design: '
    'root-navigator screens have no MicLayerScope)',
    (tester) async {
      final registry = MicTargetRegistry();
      final branchTarget = _FakeMicTarget(
        prompt: const MicPrompt(actionLabel: 'branch'),
      );
      registry.register(branchTarget, layer: MicLayer.branch);
      final rootTarget = _FakeMicTarget(
        prompt: const MicPrompt(actionLabel: 'root'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [micTargetRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            home: MicTargetScope(target: rootTarget, child: const SizedBox()),
          ),
        ),
      );

      // Root always wins over a branch entry (registry.resolve()'s own
      // precedence) — proves this registered on the root stack.
      final (resolved, _) = registry.resolve();
      expect(resolved, same(rootTarget));
    },
  );

  testWidgets('inside a MicLayerScope, registers on that exact branch stack', (
    tester,
  ) async {
    final registry = MicTargetRegistry();
    final branch0Target = _FakeMicTarget(
      prompt: const MicPrompt(actionLabel: 'branch0'),
    );
    final branch1Target = _FakeMicTarget(
      prompt: const MicPrompt(actionLabel: 'branch1'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [micTargetRegistryProvider.overrideWithValue(registry)],
        child: MaterialApp(
          home: Column(
            children: [
              MicLayerScope(
                branch: 0,
                child: MicTargetScope(
                  target: branch0Target,
                  child: const SizedBox(),
                ),
              ),
              MicLayerScope(
                branch: 1,
                child: MicTargetScope(
                  target: branch1Target,
                  child: const SizedBox(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    registry.setActiveBranch(0);
    var (resolved, _) = registry.resolve();
    expect(resolved, same(branch0Target));

    registry.setActiveBranch(1);
    (resolved, _) = registry.resolve();
    expect(resolved, same(branch1Target));
  });
}
