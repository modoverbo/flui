import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:material_ui/material_ui.dart';

/// Word progress states (docs/brand.md §8).
enum WordStateKind { nueva, practica, tuya }

class StateChip extends StatelessWidget {
  const new({required this.state, super.key});

  final WordStateKind state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, background, foreground, glyph) = switch (state) {
      // "Nueva" is one of yellow's four roles: the word of the day.
      WordStateKind.nueva => (
        l10n.wordStateNew,
        FluiColors.yellowElectric,
        FluiColors.charcoal,
        FluiGlyph.wordOfTheDay,
      ),
      WordStateKind.practica => (
        l10n.wordStatePractice,
        FluiColors.greenSecondary,
        FluiColors.cream,
        FluiGlyph.review,
      ),
      WordStateKind.tuya => (
        l10n.wordStateOwned,
        FluiColors.greenDeep,
        FluiColors.cream,
        FluiGlyph.achievement,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: FluiRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FluiGlyphIcon(glyph, size: FluiIconSize.inline, color: foreground),
            const SizedBox(width: 6),
            Text(
              FluiTypeScale.labelText(label),
              style: FluiTypeScale.compact.label.copyWith(color: foreground),
              semanticsLabel: label,
            ),
          ],
        ),
      ),
    );
  }
}
