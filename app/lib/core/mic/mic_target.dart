import 'dart:async';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:meta/meta.dart';

/// Which stack of the registry a [MicTarget] is registered against (design
/// §19.4, D24): [root] for root-navigator screens (diagnosis, `/session`);
/// [branch] for a shell branch's own screens, one stack per branch index.
enum MicLayer { root, branch }

/// What the mic's contextual label/hint should read for the currently
/// resolved [MicTarget] (design §19.2).
@immutable
final class MicPrompt {
  const new({required this.actionLabel, this.hint});

  final String actionLabel;
  final String? hint;
}

/// A CTA offered alongside a [MicBlocked] explanation (design §19.5,
/// §19.6). [route] is the router location to navigate to; a null [route]
/// means the action re-attempts the gesture itself (e.g. re-requesting a
/// previously denied permission) instead of navigating anywhere.
@immutable
final class MicBlockedCta {
  const new({required this.label, this.route});

  final String label;
  final String? route;
}

/// Whether/how a [MicTarget] can currently be triggered (design §19.2).
@immutable
sealed class MicAvailability {
  const new();
}

/// Ready to record immediately on the next gesture.
final class MicReady extends MicAvailability {
  const new();
}

/// An analysis is already in flight for this target; explained, never
/// silently ignored.
final class MicBusy extends MicAvailability {
  const new(this.message);

  final String message;
}

/// Cannot record right now; [message] (and optional [cta]) explains why —
/// a blocked mic is never silently inert (D31). Also reused as
/// `MicIdle.block`'s type for a controller-level latch (design §19.5),
/// since both describe the exact same "explained, blocked" shape.
final class MicBlocked extends MicAvailability {
  const new(this.message, {this.cta});

  final String message;
  final MicBlockedCta? cta;
}

/// This target has nothing to offer right now; the registry skips it and
/// resolves the entry below it (or the fallback) instead of blocking on it
/// (design §19.4).
final class MicPassThrough extends MicAvailability {
  const new();
}

/// The first activation only runs [onActivate] (typically showing a
/// prompt) — no capture starts; the NEXT activation records (design
/// §19.13/D40, wired fully in U23e). The triggering gesture is consumed:
/// it is never treated as a pointer-down expecting a matching pointer-up.
final class MicPrepare extends MicAvailability {
  const new(this.actionLabel, this.onActivate);

  final String actionLabel;
  final Future<void> Function() onActivate;
}

/// What happened after a captured [RecordedAudio] was handed to a
/// [MicTarget] (design §19.2, D25).
@immutable
sealed class MicDelivery {
  const new();
}

final class MicAccepted extends MicDelivery {
  const new();
}

final class MicAccessRequired extends MicDelivery {
  const new();
}

final class MicDailyLimitReached extends MicDelivery {
  const new();
}

final class MicDeliveryFailed extends MicDelivery {
  const new(this.message);

  final String message;
}

/// A screen's spoken action, registered with `MicTargetRegistry` so the
/// shell's single mic can resolve and trigger whichever one is currently
/// on top (design §19.2, §19.4). Feature-agnostic: `MicController` never
/// analyzes audio itself, it only calls [deliver] (D25).
abstract interface class MicTarget {
  MicPrompt get prompt;

  /// Clamped to a 60s ceiling regardless of the value reported here
  /// (design D42, enforced by `HoldToRecord`).
  Duration get maxDuration;

  MicAvailability get availability;

  /// Fires whenever [prompt]/[maxDuration]/[availability] change, so the
  /// controller/UI can re-render without polling.
  Stream<void> get changes;

  Future<MicDelivery> deliver(RecordedAudio audio);
}

/// The handle returned by `MicTargetRegistry.register`. A widget calls
/// [update] on rebuild (`didUpdateWidget`) and [dispose] on teardown.
abstract interface class MicRegistration {
  void update(MicTarget target);
  void dispose();
}

/// The registry's default fallback (design §19.4, D27): explains that
/// there is nothing to record right now rather than silently doing
/// nothing. Superseded by `QuickPracticeTarget` in U23e.
final class ExplainedFallbackTarget implements MicTarget {
  const new();

  @override
  MicPrompt get prompt => const MicPrompt(actionLabel: 'Practicar en voz alta');

  @override
  Duration get maxDuration => const Duration(seconds: 30);

  @override
  MicAvailability get availability => const MicBlocked(
    'Elige un reto en Entrenar para empezar a hablar.',
    cta: MicBlockedCta(label: 'Ir a Entrenar', route: '/train'),
  );

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<MicDelivery> deliver(RecordedAudio audio) async =>
      const MicDeliveryFailed('No hay ningún reto activo para grabar.');
}
