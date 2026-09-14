import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flui/features/themes/presentation/widgets/theme_choice_card.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:material_ui/material_ui.dart' hide Theme;

/// The Spanish name of a family, as a person would say it.
String themeFamilyLabel(AppLocalizations l10n, ThemeFamily family) =>
    switch (family) {
      ThemeFamily.trabajo => l10n.themeFamilyTrabajo,
      ThemeFamily.social => l10n.themeFamilySocial,
      ThemeFamily.publico => l10n.themeFamilyPublico,
      ThemeFamily.precision => l10n.themeFamilyPrecision,
      ThemeFamily.emocion => l10n.themeFamilyEmocion,
    };

/// Opens the full list of offered themes and returns the chosen one.
///
/// The daily prompt shows three cards, because that is where choice helps most
/// (Patall, Cooper and Robinson 2008). This sheet is the door for everyone
/// else: a long list is not harmful, merely not more helpful (Scheibehenne,
/// Greifeneder and Todd 2010), so it is a door, not the front of the screen.
Future<Theme?> showThemeExplorer(
  BuildContext context, {
  required List<Theme> themes,
  String? selectedId,
}) => showModalBottomSheet<Theme>(
  context: context,
  isScrollControlled: true,
  backgroundColor: FluiColors.cream,
  shape: const RoundedRectangleBorder(borderRadius: FluiRadii.sheetTop),
  builder: (context) =>
      ThemeExplorerSheet(themes: themes, selectedId: selectedId),
);

/// Every offered theme, grouped by family.
class ThemeExplorerSheet extends StatelessWidget {
  const new({required this.themes, super.key, this.selectedId});

  final List<Theme> themes;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = context.layout;
    final families = [
      for (final family in ThemeFamily.values)
        (
          family,
          [
            for (final theme in themes)
              if (theme.family == family) theme,
          ],
        ),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FluiSpacing.ml),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: FluiSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  l10n.themeExploreTitle,
                  style: layout.type.titleM.copyWith(
                    color: FluiColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(height: FluiSpacing.xxs),
              Text(
                l10n.themeExploreBody,
                style: layout.type.body.copyWith(color: FluiColors.gray),
              ),
              const SizedBox(height: FluiSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (family, group) in families)
                        if (group.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              top: FluiSpacing.sm,
                              bottom: FluiSpacing.xs,
                            ),
                            child: FluiLabel(themeFamilyLabel(l10n, family)),
                          ),
                          for (final theme in group) ...[
                            ThemeChoiceCard(
                              theme: theme,
                              selected: theme.id == selectedId,
                              onTap: () => Navigator.of(context).pop(theme),
                            ),
                            const SizedBox(height: FluiSpacing.sm),
                          ],
                        ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FluiSpacing.sm),
              FluiButton.outline(
                label: l10n.themeExploreClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: FluiSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
