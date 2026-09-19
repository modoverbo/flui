import 'dart:async';
import 'dart:math' as math;

import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/shared/widgets/organic_blob.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// The bubble's six states, per `docs/redesign/05-bubble-state-machine.md`
/// §3. Supersedes the old `VoiceOrbState` (which had no `error` value).
enum BubbleState { idle, ready, recording, processing, result, error }

/// The state-machine-aware wrapper around [OrganicBlob]. Owns the
/// idle/ready/recording/processing/result/error states and their motion —
/// breathing, pulse, contraction — as internal behaviour: the caller only
/// sets [state] (and, while recording, the already-smoothed [amplitude]
/// from the pipeline — smoothing happens upstream, in
/// `AudioReactiveBubble`, so this widget stays testable without a real
/// animation pump).
///
/// Replaces `VoiceOrb` (`features/speaking/presentation/widgets/voice_orb.dart`);
/// because the same bubble object is also the logo/welcome-screen
/// centerpiece it now lives in `shared/widgets/`.
class SpeakingBubble extends StatefulWidget {
  const new({
    required this.state,
    super.key,
    this.amplitude = 0.0,
    this.size = 188,
    this.onTap,
    this.recordingSeconds,
    this.onStop,
  });

  /// The current bubble state.
  final BubbleState state;

  /// Already-smoothed drive value, `0..1`. Only meaningful while
  /// [state] is [BubbleState.recording].
  final double amplitude;

  /// The paint area's side length (square).
  final double size;

  /// Tap handler. Enabled in every state, but only [BubbleState.ready]
  /// plays a tap-response radial wave before invoking it.
  final VoidCallback? onTap;

  /// Elapsed recording seconds, shown as a visible timer while
  /// [state] is [BubbleState.recording]. `null` hides the timer.
  final int? recordingSeconds;

  /// Stop-recording callback. When non-null and [state] is
  /// [BubbleState.recording], an obvious stop affordance is shown.
  final VoidCallback? onStop;

  @override
  State<SpeakingBubble> createState() => _SpeakingBubbleState();
}

class _SpeakingBubbleState extends State<SpeakingBubble>
    with TickerProviderStateMixin {
  // Drives the shape's slow organic drift (the `seed` fed to
  // [OrganicBlob]) across every state so the blob never looks frozen
  // between breaths. Stopped outright under reduced motion.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );

  // Drives the state-specific scale motion: a repeating breathing loop
  // for idle/ready/processing, or a one-shot pulse/contraction for
  // result/error. Its duration and repeat mode are reconfigured whenever
  // [BubbleState] changes, in [_configureForState].
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: _idleBreathDuration,
  );

  // One-shot tap-response wave for the `ready` state
  // (`06-motion-spec.md` row: "tap response, radial-wave expansion,
  // 250-450ms").
  late final AnimationController _tapWave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  static const _idleBreathDuration = Duration(milliseconds: 2500);
  static const _readyBreathDuration = Duration(milliseconds: 2200);
  static const _processingBreathDuration = Duration(milliseconds: 1800);
  static const _idleBreathAmplitude = 0.015; // scale 1.00 -> 1.015
  static const _readyBreathAmplitude = 0.03; // a bigger, "inviting" breath
  static const _processingRestScale = 0.94; // contraction, not a spinner
  static const _processingBreathAmplitude = 0.02; // 0.94 -> 0.96

  bool _reduced = false;
  BubbleState? _configuredFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _configureForState());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = FluiMotion.reduced(context);
    _configureForState();
  }

  @override
  void didUpdateWidget(covariant SpeakingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _configuredFor = null;
      _configureForState();
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _breath.dispose();
    _tapWave.dispose();
    super.dispose();
  }

  void _configureForState() {
    if (!mounted || _configuredFor == widget.state) return;
    _configuredFor = widget.state;

    if (_reduced) {
      _life
        ..stop()
        ..value = 0;
      _breath
        ..stop()
        ..value = 0;
      return;
    }

    if (!_life.isAnimating) {
      _life.repeat();
    }

    switch (widget.state) {
      case BubbleState.idle:
        _breath
          ..duration = _idleBreathDuration
          ..value = 0
          ..repeat(reverse: true);
      case BubbleState.ready:
        _breath
          ..duration = _readyBreathDuration
          ..value = 0
          ..repeat(reverse: true);
      case BubbleState.processing:
        _breath
          ..duration = _processingBreathDuration
          ..value = 0
          ..repeat(reverse: true);
      case BubbleState.recording:
        _breath.stop();
      case BubbleState.result:
        _breath
          ..value = 0
          ..animateTo(1, duration: const Duration(milliseconds: 380));
      case BubbleState.error:
        _breath.value = 0;
        unawaited(
          _breath
              .animateTo(1, duration: const Duration(milliseconds: 260))
              .then((_) {
                if (!mounted || widget.state != BubbleState.error || _reduced) {
                  return;
                }
                // "then return to idle breathing"
                // (`05-bubble-state-machine.md` §3): the contraction is a
                // brief interruption, not a new resting state.
                _breath
                  ..duration = _idleBreathDuration
                  ..value = 0
                  ..repeat(reverse: true);
              }),
        );
    }
  }

  void _handleTap() {
    if (widget.state == BubbleState.ready && !_reduced) {
      _tapWave
        ..value = 0
        ..forward();
    }
    widget.onTap?.call();
  }

  double _scaleFor(double breathT) {
    switch (widget.state) {
      case BubbleState.idle:
        return 1.0 + _idleBreathAmplitude * Curves.easeInOut.transform(breathT);
      case BubbleState.ready:
        return 1.0 +
            _readyBreathAmplitude * Curves.easeInOut.transform(breathT);
      case BubbleState.processing:
        return _processingRestScale +
            _processingBreathAmplitude * Curves.easeInOut.transform(breathT);
      case BubbleState.recording:
        return _recordingScale(widget.amplitude);
      case BubbleState.result:
        return _resultScale(breathT);
      case BubbleState.error:
        return _errorScale(breathT);
    }
  }

  /// Piecewise-linear through the spec'd low/med/high anchors
  /// (`~1.02/1.08/1.15`), continuous in between.
  static double _recordingScale(double amplitude) {
    final a = amplitude.isFinite ? amplitude.clamp(0.0, 1.0) : 0.0;
    if (a <= 0.5) return 1.02 + (1.08 - 1.02) * (a / 0.5);
    return 1.08 + (1.15 - 1.08) * ((a - 0.5) / 0.5);
  }

  /// One-shot: pulse up to 1.06, settle back to 1.0, then hold.
  static double _resultScale(double t) {
    if (t >= 1) return 1;
    if (t < 0.5) return 1 + 0.06 * Curves.easeOut.transform(t / 0.5);
    return 1.06 - 0.06 * Curves.easeIn.transform((t - 0.5) / 0.5);
  }

  /// One-shot: a brief, small, non-alarming contraction.
  static double _errorScale(double t) {
    if (t >= 1) return 1;
    if (t < 0.5) return 1 - 0.10 * Curves.easeOut.transform(t / 0.5);
    return 0.90 + 0.10 * Curves.easeIn.transform((t - 0.5) / 0.5);
  }

  double _wobbleFor() => switch (widget.state) {
    BubbleState.recording =>
      widget.amplitude.isFinite ? widget.amplitude.clamp(0.0, 1.0) : 0.0,
    BubbleState.ready => 0.08,
    _ => 0.0,
  };

  List<Color> _colorsFor() => switch (widget.state) {
    BubbleState.idle => const [FluiColors.lavender, FluiColors.electricBlue],
    BubbleState.ready => const [FluiColors.aqua, FluiColors.electricBlue],
    BubbleState.recording => [
      Color.lerp(
        FluiColors.electricBlue,
        FluiColors.coral,
        widget.amplitude.isFinite ? widget.amplitude.clamp(0.0, 1.0) : 0.0,
      )!,
      FluiColors.coral,
    ],
    BubbleState.processing => const [FluiColors.lavender, FluiColors.aqua],
    BubbleState.result => const [FluiColors.acidLime, FluiColors.aqua],
    BubbleState.error => const [FluiColors.amber, FluiColors.coral],
  };

  String _announcementFor(AppLocalizations l10n) => switch (widget.state) {
    BubbleState.idle => l10n.bubbleStateIdle,
    BubbleState.ready => l10n.bubbleStateReady,
    BubbleState.recording => l10n.bubbleStateRecording,
    BubbleState.processing => l10n.bubbleStateProcessing,
    BubbleState.result => l10n.bubbleStateResult,
    BubbleState.error => l10n.bubbleStateError,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduced = FluiMotion.reduced(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      _configuredFor = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _configureForState();
      });
    }

    Widget bubble = AnimatedBuilder(
      animation: Listenable.merge([_life, _breath, _tapWave]),
      builder: (context, _) {
        final breathT = reduced ? 0.0 : _breath.value;
        final scale = _scaleFor(breathT) + _tapWave.value * 0.04;
        final seed = reduced ? 0.0 : _life.value * math.pi * 2;
        final wobble = _wobbleFor();
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (widget.state == BubbleState.recording)
              CustomPaint(
                size: Size.square(widget.size * 1.6),
                painter: _ReactiveRingsPainter(
                  amplitude: wobble,
                  phase: seed,
                  color: FluiColors.electricBlue,
                ),
              ),
            if (widget.state == BubbleState.ready && _tapWave.value > 0)
              CustomPaint(
                size: Size.square(widget.size * 1.6),
                painter: _TapWavePainter(
                  progress: _tapWave.value,
                  color: FluiColors.aqua,
                ),
              ),
            OrganicBlob(
              size: widget.size,
              wobble: wobble,
              seed: seed,
              scale: scale,
              colors: _colorsFor(),
              glowStrength: widget.state == BubbleState.ready
                  ? 0.6 + 0.4 * Curves.easeInOut.transform(breathT)
                  : 1.0,
            ),
          ],
        );
      },
    );

    bubble = RepaintBoundary(child: bubble);

    return Semantics(
      label: _announcementFor(l10n),
      liveRegion: true,
      button: widget.onTap != null,
      child: GestureDetector(
        onTap: widget.onTap != null ? _handleTap : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bubble,
            if (widget.state == BubbleState.recording &&
                widget.recordingSeconds != null) ...[
              const SizedBox(height: 12),
              Semantics(
                container: true,
                label: l10n.bubbleRecordingSeconds(widget.recordingSeconds!),
                excludeSemantics: true,
                child: Text(
                  '${widget.recordingSeconds} s',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: FluiColors.gray,
                  ),
                ),
              ),
            ],
            if (widget.state == BubbleState.recording &&
                widget.onStop != null) ...[
              const SizedBox(height: 8),
              Semantics(
                container: true,
                button: true,
                label: l10n.bubbleStopRecording,
                child: GestureDetector(
                  onTap: widget.onStop,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: FluiColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.square,
                      size: 18,
                      color: FluiColors.cream,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Recording-only: two staggered expanding rings plus perimeter particle
/// displacement, both scaled by [amplitude] — "you're being heard, right
/// now" (`06-motion-spec.md` row 7). Paint-only, no layout per frame.
class _ReactiveRingsPainter extends CustomPainter {
  const new({
    required this.amplitude,
    required this.phase,
    required this.color,
  });

  final double amplitude;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitude <= 0.02) return;
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * 0.225;

    for (var ring = 0; ring < 2; ring++) {
      final t = ((phase / (math.pi * 2)) + ring * 0.5) % 1.0;
      final radius = baseRadius * (1 + t * (0.6 + amplitude * 0.6));
      final opacity = (1 - t) * amplitude * 0.35;
      if (opacity <= 0) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: opacity),
      );
    }

    const particleCount = 8;
    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * math.pi * 2 + phase * 0.3;
      final r = baseRadius * 1.15 + amplitude * 14;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawCircle(
        point,
        1.5 + amplitude * 1.5,
        Paint()..color = color.withValues(alpha: 0.25 + amplitude * 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_ReactiveRingsPainter oldDelegate) =>
      oldDelegate.amplitude != amplitude ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color;
}

/// `ready`-state tap response: a single expanding ring, 250-450ms.
class _TapWavePainter extends CustomPainter {
  const new({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * 0.225;
    final radius = baseRadius * (1 + progress * 0.9);
    final opacity = (1 - progress) * 0.5;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_TapWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
