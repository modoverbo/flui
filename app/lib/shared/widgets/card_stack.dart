import 'dart:math' as math;

import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/shared/motion/card_transition.dart';
import 'package:material_ui/material_ui.dart';

/// Composites up to three `TrainingCard`s as a physical stack and animates
/// the enter/exit/promotion transition between them
/// (`docs/redesign/03-card-stack-spec.md`, `07-component-hierarchy.md`).
///
/// A dumb widget: it receives already-built cards (front first) and reports
/// intent outward — it never touches `SessionFlow`/`SessionController`
/// itself. [cards] changing identity (its first card's [Key]) is read as
/// "the caller advanced"; `CardStack` then plays the exit/promotion
/// animation before settling on the new front card and calling
/// [onFrontCardExitComplete].
class CardStack extends StatefulWidget {
  const new({
    required this.cards,
    super.key,
    this.onFrontCardExitComplete,
    this.onSwipeAdvance,
    this.swipeEnabled = false,
  });

  /// Already-built cards, front first, length at most 3. Each must carry a
  /// stable [Key] (`docs/redesign/03-card-stack-spec.md` §4) so a promoted
  /// card animates from its current on-screen state instead of snapping.
  final List<Widget> cards;

  /// Called once the front card's exit animation (and the promotion behind
  /// it) has fully settled.
  final VoidCallback? onFrontCardExitComplete;

  /// Called when a swipe past the threshold is released on the front card.
  /// Only used when [swipeEnabled] is true.
  final VoidCallback? onSwipeAdvance;

  /// Whether the front card may be swiped to advance
  /// (`03-card-stack-spec.md` §2 — read-only steps only). Ignored (swipe
  /// never enabled) under reduced motion, per §6.
  final bool swipeEnabled;

  static const List<double> scales = [1.00, 0.94, 0.89];
  static const List<double> yOffsets = [0, 18, 34];
  static const List<double> opacities = [1.00, 0.85, 0.55];

  /// The stack's own stable card height, capped so positions 1/2 always
  /// peek out from beneath the front card by a visible margin — the Y
  /// offsets above are logical pixels, not a fraction of the card, so an
  /// unbounded card height would shrink that peek to nothing on a tall
  /// viewport. Content taller than this scrolls inside `TrainingCard`
  /// instead of growing the card.
  static const double maxCardHeight = 360;

  /// The rest geometry of stack [position] (0 front, 1 next, 2 next+1).
  static CardPositionState restState(int position) => CardPositionState(
    scale: scales[position],
    y: yOffsets[position],
    opacity: opacities[position],
  );

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> {
  List<Widget>? _previousCards;
  bool _transitioning = false;
  double _dragDx = 0;
  double _dragVelocity = 0;

  static Key? _frontKey(List<Widget> cards) =>
      cards.isEmpty ? null : cards.first.key;

  @override
  void didUpdateWidget(covariant CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.isNotEmpty &&
        _frontKey(oldWidget.cards) != _frontKey(widget.cards)) {
      _previousCards = oldWidget.cards;
      _transitioning = true;
      _dragDx = 0;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragDx += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    const distanceThreshold = 120.0;
    const velocityThreshold = 700.0;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragDx.abs() > distanceThreshold ||
        velocity.abs() > velocityThreshold) {
      _dragVelocity = velocity;
      widget.onSwipeAdvance?.call();
    }
    setState(() => _dragDx = 0);
  }

  void _completeTransition() {
    if (!mounted) return;
    setState(() {
      _previousCards = null;
      _transitioning = false;
    });
    widget.onFrontCardExitComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (FluiMotion.reduced(context)) {
      // 03-card-stack-spec.md §6: only the front card renders, full-bleed;
      // positions 1/2 are never composited and advance is an instant swap.
      return widget.cards.isEmpty
          ? const SizedBox.shrink()
          : widget.cards.first;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final height = constraints.hasBoundedHeight
            ? math.min(constraints.maxHeight, CardStack.maxCardHeight)
            : CardStack.maxCardHeight;
        if (_transitioning && _previousCards != null) {
          return _buildTransition(_previousCards!, widget.cards, width, height);
        }
        return _buildStatic(widget.cards, width, height);
      },
    );
  }

  /// Every card (front and preview alike) is boxed at the same [width]x
  /// [height] before any scale/translate is applied, so the geometry table
  /// (`03-card-stack-spec.md` §1) always peeks the back cards out from
  /// beneath the front one — regardless of how tall each card's own content
  /// happens to be. Deliberately keyless: the card's own identity `Key`
  /// stays on [card] itself (read by callers via `cards[i].key`), so this
  /// wrapper never shadows it for `find.byKey` or promotion bookkeeping.
  static Widget _sized(Widget card, double? width, double height) =>
      SizedBox(width: width, height: height, child: card);

  Widget _buildStatic(List<Widget> cards, double? width, double height) {
    final layers = <Widget>[];
    for (var i = cards.length - 1; i >= 0; i--) {
      final rest = CardStack.restState(i);
      Widget layer = Transform.translate(
        offset: Offset(i == 0 ? _dragDx : 0, rest.y),
        child: Opacity(
          opacity: rest.opacity,
          child: Transform.scale(
            scale: rest.scale,
            child: _sized(cards[i], width, height),
          ),
        ),
      );
      if (i != 0) {
        layer = IgnorePointer(child: layer);
      } else if (widget.swipeEnabled) {
        layer = GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: layer,
        );
      }
      layers.add(layer);
    }
    // No `Positioned.fill`: `SessionPage` hosts the stack inside a
    // `SingleChildScrollView` (unbounded height), and a `Stack` needs
    // bounded constraints to size `Positioned.fill` children. Plain
    // (non-positioned) children size the `Stack` to its largest child
    // instead, which works inside a scroll view and matches the spec's own
    // "cards share the same horizontal center" rule via `alignment`.
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: layers,
    );
  }

  Widget _buildTransition(
    List<Widget> previous,
    List<Widget> next,
    double? width,
    double height,
  ) {
    // Sign matches swipe direction if swipe-triggered; button-triggered
    // exits are always a gentle counter-clockwise −6° (03-card-stack-spec.md
    // §3).
    final sign = _dragVelocity < 0 ? -1.0 : (_dragVelocity > 0 ? 1.0 : -1.0);
    final exitRotation = sign * 6 * math.pi / 180;
    _dragVelocity = 0;

    final layers = <Widget>[
      // Back to front: new entrants and promotions first, the exiting
      // front-card layer painted last so it stays on top while it leaves.
      for (var i = next.length - 1; i >= 0; i--)
        if (i + 1 >= previous.length)
          _EnterAtRest(position: i, child: _sized(next[i], width, height))
        else
          CardTransition(
            key: ValueKey('promote-${next[i].key}'),
            from: CardStack.restState(i + 1),
            to: CardStack.restState(i),
            spring: fluiSpringStandard,
            becomesInteractive: i == 0,
            child: _sized(next[i], width, height),
          ),
      CardTransition(
        key: ValueKey('exit-${previous.first.key}'),
        from: const CardPositionState(scale: 1, y: 0, opacity: 1),
        to: CardPositionState(
          scale: 0.86,
          y: 420,
          opacity: 0,
          rotation: exitRotation,
        ),
        spring: fluiSpringStandard,
        onComplete: _completeTransition,
        child: _sized(previous.first, width, height),
      ),
    ];
    // See `_buildStatic`: no `Positioned.fill`, so the `Stack` still sizes
    // correctly inside `SessionPage`'s unbounded-height scroll view.
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: layers,
    );
  }
}

/// A card entering position 2 from the lookahead: it wasn't composited
/// before, so it has no physical "before" state — it simply appears at
/// position 2's rest geometry with a quick opacity fade-in
/// (`03-card-stack-spec.md` §3), curve-based rather than spring-based.
class _EnterAtRest extends StatefulWidget {
  const new({required this.position, required this.child});

  final int position;
  final Widget child;

  @override
  State<_EnterAtRest> createState() => _EnterAtRestState();
}

class _EnterAtRestState extends State<_EnterAtRest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: FluiMotion.quick, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FluiMotion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rest = CardStack.restState(widget.position);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Opacity(
          opacity: FluiMotion.enter.transform(_controller.value) * rest.opacity,
          child: Transform.translate(
            offset: Offset(0, rest.y),
            child: Transform.scale(scale: rest.scale, child: widget.child),
          ),
        ),
      ),
    );
  }
}
