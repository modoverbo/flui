import 'dart:async';

import 'package:flui/core/theme/flui_motion.dart';
import 'package:material_ui/material_ui.dart';

/// One card's position in the stack: scale, downward Y offset (logical
/// pixels), opacity and rotation (radians), per
/// `docs/redesign/03-card-stack-spec.md` §1/§3.
@immutable
class CardPositionState {
  const new({
    required this.scale,
    required this.y,
    required this.opacity,
    this.rotation = 0,
  });

  factory lerp(CardPositionState a, CardPositionState b, double t) =>
      CardPositionState(
        scale: a.scale + (b.scale - a.scale) * t,
        y: a.y + (b.y - a.y) * t,
        opacity: (a.opacity + (b.opacity - a.opacity) * t).clamp(0.0, 1.0),
        rotation: a.rotation + (b.rotation - a.rotation) * t,
      );

  final double scale;
  final double y;
  final double opacity;
  final double rotation;

  @override
  bool operator ==(Object other) =>
      other is CardPositionState &&
      other.scale == scale &&
      other.y == y &&
      other.opacity == opacity &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(scale, y, opacity, rotation);
}

/// A single-child, spring-driven interpolation between two
/// [CardPositionState]s — the motion primitive `CardStack` composes three of
/// (`docs/redesign/07-component-hierarchy.md`). Independently testable: feed
/// it `from`/`to` and a spring, and assert the interpolated transform at a
/// given animation progress.
///
/// Honours `MediaQuery.disableAnimationsOf`: when reduced motion is on, the
/// child settles at [to] instantly, with no intermediate animated frame.
class CardTransition extends StatefulWidget {
  const new({
    required this.from,
    required this.to,
    required this.spring,
    required this.child,
    super.key,
    this.onComplete,
    this.velocity = 0,
    this.becomesInteractive = false,
  });

  final CardPositionState from;
  final CardPositionState to;
  final SpringDescription spring;
  final Widget child;
  final VoidCallback? onComplete;

  /// Seed velocity for the spring simulation — 0 for a programmatic
  /// trigger, or a drag gesture's release velocity.
  final double velocity;

  /// Whether this layer is the one promoting into the interactive front
  /// position (position 1 → 0). Per `03-card-stack-spec.md` §3, it only
  /// lifts `IgnorePointer` once the animation crosses ~90% completion —
  /// every other layer (the exit, and position 2 → 1) stays non-interactive
  /// for the whole transition.
  final bool becomesInteractive;

  @override
  State<CardTransition> createState() => _CardTransitionState();
}

class _CardTransitionState extends State<CardTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _notifiedComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() {}))
      ..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _notifiedComplete) return;
    _notifiedComplete = true;
    widget.onComplete?.call();
  }

  void _start() {
    if (_started) return;
    _started = true;
    if (FluiMotion.reduced(context)) {
      // Settle instantly: the value lands before the first build, so there
      // is no intermediate animated frame to observe.
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _notifiedComplete) return;
        _notifiedComplete = true;
        widget.onComplete?.call();
      });
      return;
    }
    unawaited(
      FluiMotion.driveSpring(
        context,
        _controller,
        widget.spring,
        to: 1,
        velocity: widget.velocity,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _controller.value;
    final state = CardPositionState.lerp(widget.from, widget.to, t);
    return IgnorePointer(
      ignoring: !widget.becomesInteractive || t < 0.9,
      child: Opacity(
        opacity: state.opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, state.y),
          child: Transform.rotate(
            angle: state.rotation,
            child: Transform.scale(scale: state.scale, child: widget.child),
          ),
        ),
      ),
    );
  }
}
