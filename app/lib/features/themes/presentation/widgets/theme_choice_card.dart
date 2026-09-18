import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
// The domain entity is called Theme, like Flutter's inherited widget. Nothing
// in this file needs the widget, so the import gives up the name instead of
// the entity giving up its own.
import 'package:material_ui/material_ui.dart' hide Theme;

/// A selectable theme: its name and the one line that says what it is for.
///
/// Deliberately not an icon tile. The design system has ten custom glyphs and
/// no pastel squares, so a theme is identified by its words.
class ThemeChoiceCard extends StatelessWidget {
  const new({
    required this.theme,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Theme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: l10n.themeChoiceSemantics(theme.name, theme.tagline),
      excludeSemantics: true,
      child: FluiCard(
        color: const [
          FluiColors.softPink,
          FluiColors.aqua,
          FluiColors.acidLime,
          FluiColors.coral,
          FluiColors.lavender,
        ][theme.sortOrder % 5],
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: FluiSpacing.ml,
          vertical: FluiSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: FluiSpacing.minTapTarget,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      theme.name,
                      style: type.titleM.copyWith(color: FluiColors.greenDeep),
                    ),
                    const SizedBox(height: FluiSpacing.xxs),
                    Text(
                      theme.tagline,
                      style: type.body.copyWith(color: FluiColors.gray),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: FluiSpacing.sm),
                const FluiGlyphIcon(
                  FluiGlyph.achievement,
                  color: FluiColors.greenDeep,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
