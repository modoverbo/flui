import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:material_ui/material_ui.dart';

/// The card-stack surface: organic rounded shape, colour resolved from the
/// hosted word's primary theme, editorial typography context, hosting
/// arbitrary step content unchanged (`docs/redesign/07-component-hierarchy.md`
/// "TrainingCard"). Purely presentational — it does not know about
/// `SessionStep`/`SessionFlow`, only the resolved theme slug and its
/// position in the stack.
class TrainingCard extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.themeSlug,
    this.position = 0,
  });

  final Widget child;

  /// The word's primary theme slug (`content/themes.yml`), or `null` when
  /// the word has none. Resolved through [FluiThemeColors.resolve], which
  /// falls back safely to [FluiThemeColors.fallback] for `null` or an
  /// unknown slug — colour resolution never throws.
  final String? themeSlug;

  /// 0 (front), 1 (next) or 2 (next+1) — drives whether the stack shadow is
  /// painted. Position itself does not set scale/Y/opacity: `CardStack`
  /// owns that geometry so it can animate it.
  final int position;

  /// `docs/redesign/03-card-stack-spec.md` §1: a single shadow under the
  /// front card sells the stack; positions 1/2 get none of their own.
  static const List<BoxShadow> cardStackShadow = [
    BoxShadow(color: Color(0x1F151426), blurRadius: 32, offset: Offset(0, 12)),
  ];

  FluiThemeColor get _theme => themeSlug == null
      ? FluiThemeColors.fallback
      : FluiThemeColors.resolve(themeSlug!);

  /// Width of the saturated edge painted around the card (see [build]).
  static const double _edgeWidth = 4;

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    // A themeless word resolves to `FluiThemeColors.fallback`, whose
    // `surface` *is* `FluiColors.paper` — indistinguishable from the page
    // background at the few pixels of peek a back card gets. That's the
    // right look for a themeless *front* card (neutral, no invented
    // colour), but a back card's entire on-screen presence is that edge —
    // give it a visible neutral instead of disappearing outright.
    final isFallback = theme == FluiThemeColors.fallback;
    final edgeColor = position == 0 || !isFallback
        ? theme.surface
        : FluiColors.gray;
    return DecoratedBox(
      // The saturated colour above, painted as the *outer* box and
      // revealed as a thin edge all the way around once the tinted inner
      // box insets by `_edgeWidth` below. A `BoxDecoration.border` would be
      // the more obvious way to draw this, but a non-default `Border`
      // doesn't reliably paint once this card is nested inside
      // `CardStack`'s scale/translate/opacity transforms — a second filled
      // `DecoratedBox` does, so that's what draws the edge here.
      decoration: BoxDecoration(
        color: edgeColor,
        borderRadius: FluiRadii.cardAll,
        boxShadow: position == 0 ? cardStackShadow : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_edgeWidth),
        child: ClipRRect(
          borderRadius: FluiRadii.cardAll,
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.tint),
            child: Material(
              color: Colors.transparent,
              // The card itself is a fixed, layout-stable box (`CardStack`
              // owns that geometry); content taller than it scrolls in
              // here instead of overflowing or growing the card
              // (`docs/redesign/03-card-stack-spec.md` §1).
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
