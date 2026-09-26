import 'dart:async';

import 'package:flui/core/audio/amplitude_pipeline.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/shared/widgets/speaking_bubble.dart';
import 'package:material_ui/material_ui.dart';

/// The integration widget: wires a raw dBFS amplitude [Stream] (typically
/// `SpeechRecorder.amplitude`) through [AmplitudePipeline] into
/// [SpeakingBubble], replacing `VoiceOrb`'s role in
/// `SpeakingChallengePage`.
///
/// Per `docs/redesign/05-bubble-state-machine.md` §4 step 4: the pipeline
/// updates once per ~120ms recorder tick, but the widget renders at 60fps
/// by interpolating between the previous and new smoothed value over that
/// window with a driven [AnimationController], rather than stepping the
/// visual value only ~8 times a second.
///
/// Deliberately painted-only (`CustomPainter`, via `OrganicBlob`/
/// `SpeakingBubble`) with no fragment-shader branch: shaders are
/// unreliable on Flutter web (flui is web-first) and would only ever be a
/// `kIsWeb == false` progressive enhancement, out of scope here.
class AudioReactiveBubble extends StatefulWidget {
  const new({
    required this.state,
    super.key,
    this.amplitudeStream,
    this.size = 188,
    this.onTap,
    this.recordingSeconds,
    this.onStop,
  });

  /// The current bubble state.
  final BubbleState state;

  /// Raw dBFS amplitude samples, e.g. `SpeechRecorder.amplitude`. `null`
  /// (or not listened to outside [BubbleState.recording]) leaves the
  /// bubble's amplitude at rest.
  final Stream<double>? amplitudeStream;

  /// The paint area's side length (square).
  final double size;

  final VoidCallback? onTap;

  /// Elapsed recording seconds, shown as a visible timer.
  final int? recordingSeconds;

  /// Stop-recording callback; shown as an obvious affordance while
  /// recording.
  final VoidCallback? onStop;

  @override
  State<AudioReactiveBubble> createState() => _AudioReactiveBubbleState();
}

class _AudioReactiveBubbleState extends State<AudioReactiveBubble>
    with SingleTickerProviderStateMixin {
  final _pipeline = AmplitudePipeline();
  StreamSubscription<double>? _subscription;
  double _previous = 0;
  double _target = 0;

  late final AnimationController _interpolation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant AudioReactiveBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      unawaited(_subscription?.cancel());
      _pipeline.reset();
      _previous = 0;
      _target = 0;
      _subscribe();
    }
  }

  void _subscribe() {
    final stream = widget.amplitudeStream;
    if (stream == null) return;
    _subscription = stream.listen(_onSample);
  }

  void _onSample(double dbfs) {
    if (!mounted) return;
    final smoothed = _pipeline.addSample(dbfs);
    final reduced = FluiMotion.reduced(context);
    if (reduced) {
      // Reduced motion: step directly to the new sample rather than
      // continuously interpolating (`05-bubble-state-machine.md` §5 —
      // amplitude reactivity stays informational, just stepped).
      setState(() {
        _previous = smoothed;
        _target = smoothed;
      });
      return;
    }
    setState(() {
      _previous = _currentInterpolated();
      _target = smoothed;
    });
    _interpolation
      ..value = 0
      ..forward();
  }

  double _currentInterpolated() =>
      _previous + (_target - _previous) * _interpolation.value;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _interpolation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _interpolation,
    builder: (context, _) => SpeakingBubble(
      state: widget.state,
      amplitude: _currentInterpolated().clamp(0.0, 1.0),
      size: widget.size,
      onTap: widget.onTap,
      recordingSeconds: widget.recordingSeconds,
      onStop: widget.onStop,
    ),
  );
}
