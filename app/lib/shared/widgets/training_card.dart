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

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.tint,
        borderRadius: FluiRadii.cardAll,
        boxShadow: position == 0 ? cardStackShadow : const [],
        border: Border(top: BorderSide(color: theme.surface, width: 4)),
      ),
      child: ClipRRect(
        borderRadius: FluiRadii.cardAll,
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}
