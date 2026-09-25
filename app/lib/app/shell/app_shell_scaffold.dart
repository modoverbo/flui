import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:material_ui/material_ui.dart';

/// Order of the shell branches. Keep in sync with `app_router.dart`.
///
/// Four tabs, not five: "Practica" became the "Repaso extra" action on Hoy
/// and "En contexto" became a section of the word detail, because both were
/// places the user had to remember to visit. "Habla" was promoted from a
/// root-only route to a real tab (`docs/redesign/02-navigation-model.md`):
/// selecting it always lands on the speaking challenge's `ready` phase, and
/// starting a challenge still takes over the full screen exactly like
/// `/session` does, via a nested root-navigator route in `app_router.dart`.
enum ShellDestination { today, words, habla, progress }

/// Navigation chrome: bottom bar on phones, side rail on wide screens.
///
/// The tab glyphs are the custom family at 22 px, never a library icon
/// inside a tinted square.
class AppShellScaffold extends StatelessWidget {
  const new({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  static FluiGlyph glyphOf(ShellDestination destination) =>
      switch (destination) {
        ShellDestination.today => FluiGlyph.onda,
        // The word-entry glyph: a dictionary entry, which is what the
        // repertoire is.
        ShellDestination.words => FluiGlyph.wordOfTheDay,
        ShellDestination.habla => FluiGlyph.microphone,
        ShellDestination.progress => FluiGlyph.streak,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      for (final destination in ShellDestination.values)
        (
          glyphOf(destination),
          switch (destination) {
            ShellDestination.today => l10n.navToday,
            ShellDestination.words => l10n.navWords,
            ShellDestination.habla => l10n.navHabla,
            ShellDestination.progress => l10n.navProgress,
          },
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < FluiBreakpoints.rail) {
          return Scaffold(
            backgroundColor: FluiColors.paper,
            body: child,
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
                  backgroundColor: FluiColors.surface,
                  indicatorColor: FluiColors.greenTint,
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      color: states.contains(WidgetState.selected)
                          ? FluiColors.ink
                          : FluiColors.gray,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: [
                    for (final (index, (glyph, label)) in items.indexed)
                      NavigationDestination(
                        icon: FluiGlyphIcon(
                          glyph,
                          size: FluiIconSize.tab,
                          color: index == selectedIndex
                              ? FluiColors.greenDeep
                              : FluiColors.gray,
                        ),
                        label: label,
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        final extended = width >= FluiBreakpoints.extendedRail;
        return Scaffold(
          backgroundColor: FluiColors.paper,
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  extended: extended,
                  minExtendedWidth: 220,
                  backgroundColor: FluiColors.paper,
                  indicatorColor: FluiColors.greenTint,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  selectedLabelTextStyle: const TextStyle(
                    color: FluiColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: FluiColors.gray,
                  ),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FluiSpacing.lg,
                    ),
                    child: extended
                        ? const FluiLogo(symbolSize: 32)
                        : const FluiSymbol(size: 32, semanticLabel: 'flui'),
                  ),
                  destinations: [
                    for (final (index, (glyph, label)) in items.indexed)
                      NavigationRailDestination(
                        icon: FluiGlyphIcon(
                          glyph,
                          size: FluiIconSize.tab,
                          color: index == selectedIndex
                              ? FluiColors.greenDeep
                              : FluiColors.gray,
                        ),
                        label: Text(label),
                        padding: const EdgeInsets.symmetric(
                          vertical: FluiSpacing.xxs,
                        ),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(
                width: 1,
                color: FluiColors.hairlineOnCream,
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
