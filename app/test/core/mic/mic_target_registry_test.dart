import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/core/mic/mic_target_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable [MicTarget] test double: [label] identifies which one
/// resolved in assertions, [availability] can be swapped after
/// construction to exercise `MicPassThrough` skipping.
final class _FakeMicTarget implements MicTarget {
  new(this.label, {MicAvailability? availability})
    : _availability = availability ?? const MicReady();

  final String label;
  MicAvailability _availability;

  @override
  MicPrompt get prompt => MicPrompt(actionLabel: label);

  @override
  Duration get maxDuration => const Duration(seconds: 30);

  @override
  MicAvailability get availability => _availability;

  set availability(MicAvailability value) => _availability = value;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async => const MicAccepted();

  @override
  String toString() => 'target($label)';
}

void main() {
  group('register/resolve precedence', () {
    test('resolve() never returns null: an empty registry resolves the '
        'default fallback', () {
      final registry = MicTargetRegistry();

      final (target, _) = registry.resolve();

      expect(target, isA<ExplainedFallbackTarget>());
    });

    test('a root registration always wins over any branch registration', () {
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget('branch'), layer: MicLayer.branch)
        ..register(_FakeMicTarget('root'), layer: MicLayer.root);

      final (target, _) = registry.resolve();

      expect((target as _FakeMicTarget).label, 'root');
    });

    test('within one stack, the most recently registered target wins '
        '(last-registered-wins)', () {
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget('first'), layer: MicLayer.branch)
        ..register(_FakeMicTarget('second'), layer: MicLayer.branch);

      final (target, _) = registry.resolve();

      expect((target as _FakeMicTarget).label, 'second');
    });

    test('disposing a non-top entry keeps the current top active, never '
        'resurfacing a stale entry below it', () {
      final registry = MicTargetRegistry();
      final first = registry.register(
        _FakeMicTarget('first'),
        layer: MicLayer.branch,
      );
      registry.register(_FakeMicTarget('second'), layer: MicLayer.branch);

      first.dispose();

      final (target, _) = registry.resolve();
      expect((target as _FakeMicTarget).label, 'second');
    });

    test('disposing the current top resurfaces the entry below it', () {
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget('first'), layer: MicLayer.branch);
      registry
          .register(_FakeMicTarget('second'), layer: MicLayer.branch)
          .dispose();

      final (target, _) = registry.resolve();
      expect((target as _FakeMicTarget).label, 'first');
    });

    test('a MicPassThrough target on top is skipped, resolving the entry '
        'below it', () {
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget('below'), layer: MicLayer.branch)
        ..register(
          _FakeMicTarget('pass', availability: const MicPassThrough()),
          layer: MicLayer.branch,
        );

      final (target, _) = registry.resolve();

      expect((target as _FakeMicTarget).label, 'below');
    });

    test('with only a MicPassThrough entry, resolve() falls through to the '
        'fallback, never null', () {
      final registry = MicTargetRegistry()
        ..register(
          _FakeMicTarget('pass', availability: const MicPassThrough()),
          layer: MicLayer.branch,
        );

      final (target, _) = registry.resolve();

      expect(target, isA<ExplainedFallbackTarget>());
    });

    test('setFallback replaces the default fallback', () {
      final registry = MicTargetRegistry()
        ..setFallback(_FakeMicTarget('custom-fallback'));

      final (target, _) = registry.resolve();

      expect((target as _FakeMicTarget).label, 'custom-fallback');
    });
  });

  group('setActiveBranch', () {
    test("resolve() only consults the active branch's own stack", () {
      final registry = MicTargetRegistry()
        ..register(_FakeMicTarget('branch0'), layer: MicLayer.branch, branch: 0)
        ..register(
          _FakeMicTarget('branch1'),
          layer: MicLayer.branch,
          branch: 1,
        );

      var (target, _) = registry.resolve();
      expect((target as _FakeMicTarget).label, 'branch0');

      registry.setActiveBranch(1);
      (target, _) = registry.resolve();
      expect((target as _FakeMicTarget).label, 'branch1');

      registry.setActiveBranch(0);
      (target, _) = registry.resolve();
      expect((target as _FakeMicTarget).label, 'branch0');
    });
  });

  group('changes', () {
    test(
      'fires on registration, disposal, and MicRegistration.update',
      () async {
        final registry = MicTargetRegistry();
        var fired = 0;
        registry.changes.listen((_) => fired++);

        final registration = registry.register(
          _FakeMicTarget('a'),
          layer: MicLayer.branch,
        );
        await Future<void>.delayed(Duration.zero);
        expect(fired, 1);

        registration.update(_FakeMicTarget('b'));
        await Future<void>.delayed(Duration.zero);
        expect(fired, 2);

        registration.dispose();
        await Future<void>.delayed(Duration.zero);
        expect(fired, 3);
      },
    );

    test('setActiveBranch to a different index fires changes (so MicController '
        "can refresh its idle prompt to the newly-active branch's target); "
        'setting the SAME index again fires nothing — AppShell calls this on '
        'every rebuild, so it must not notify/churn when the branch has not '
        'actually changed', () async {
      final registry = MicTargetRegistry();
      var fired = 0;
      registry.changes.listen((_) => fired++);

      registry.setActiveBranch(1);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 1);

      // Same index again (as AppShell does on every rebuild while the
      // user stays on the same tab) — no notification.
      registry.setActiveBranch(1);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 1);

      registry.setActiveBranch(0);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 2);
    });
  });

  group('token identity', () {
    test('resolve() returns a token identifying this exact registration', () {
      final registry = MicTargetRegistry();
      final registration = registry.register(
        _FakeMicTarget('a'),
        layer: MicLayer.branch,
      );

      final (_, token) = registry.resolve();

      expect(identical(token, registration), isTrue);
    });
  });
}
