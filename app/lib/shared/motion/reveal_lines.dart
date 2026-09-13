import 'package:flui/core/theme/flui_motion.dart';
import 'package:material_ui/material_ui.dart';

/// The word reveal: each line slides up from behind its own mask, 40 ms
/// apart, settling from 1.02 to 1.0.
///
/// With "reduce motion" on, the lines are simply there.
class RevealLines extends StatefulWidget {
  const new({
    required this.children,
    super.key,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.stagger = FluiMotion.wordRevealStagger,
    this.duration = FluiMotion.wordReveal,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final Duration stagger;
  final Duration duration;

  @override
  State<RevealLines> createState() => _RevealLinesState();
}

class _RevealLinesState extends State<RevealLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );

  Duration get _total =>
      widget.duration +
      widget.stagger * (widget.children.length - 1).clamp(0, 1 << 20);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FluiMotion.reduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value != 1) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(RevealLines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _controller.duration = _total;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _total.inMicroseconds;
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, child) in widget.children.indexed)
          _RevealLine(
            animation: CurvedAnimation(
              parent: _controller,
              curve: Interval(
                total == 0
                    ? 0
                    : (widget.stagger.inMicroseconds * index) / total,
                total == 0
                    ? 1
                    : (widget.stagger.inMicroseconds * index +
                              widget.duration.inMicroseconds) /
                          total,
                curve: FluiMotion.enter,
              ),
            ),
            child: child,
          ),
      ],
    );
  }
}

class _RevealLine extends StatelessWidget {
  const new({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          return Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: Transform.scale(
              scale: 1 + (FluiMotion.wordRevealScale - 1) * (1 - t),
              alignment: Alignment.bottomLeft,
              child: Opacity(opacity: t, child: child),
            ),
          );
        },
        child: child,
      ),
    );
  }
}
