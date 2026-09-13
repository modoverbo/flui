import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:material_ui/material_ui.dart';

/// A large, selectable time budget ("10 min · 1 palabra nueva + repaso").
class BudgetChoiceCard extends StatelessWidget {
  const new({
    required this.minutes,
    required this.line,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int minutes;
  final String line;
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
      label: l10n.timeBudgetChoiceSemantics(minutes, line),
      excludeSemantics: true,
      child: FluiCard(
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
              SizedBox(
                width: 92,
                child: Text(
                  l10n.timeBudgetMinutes(minutes),
                  style: type.titleM.copyWith(color: FluiColors.greenDeep),
                ),
              ),
              const SizedBox(width: FluiSpacing.sm),
              Expanded(
                child: Text(
                  line,
                  style: type.body.copyWith(color: FluiColors.charcoal),
                ),
              ),
              if (selected)
                const FluiGlyphIcon(
                  FluiGlyph.achievement,
                  color: FluiColors.greenDeep,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
