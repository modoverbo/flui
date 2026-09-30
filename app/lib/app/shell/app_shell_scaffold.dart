import 'package:flui/app/shell/flui_bottom_bar.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/presentation/mic_button.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Order of the shell branches (U16). ENTRENAR carries the training-lab
/// mode picker (`TrainingLabPage`), and its own loop routes are branch
/// children (no root-navigator take-over, design D30). Keep in sync with
/// `app_router.dart`'s shell branches.
enum ShellDestination { today, train, words, progress }

/// Navigation chrome: bottom bar on phones, side rail on wide screens.
///
/// The tab glyphs are the custom family at 22 px, never a library icon
/// inside a tinted square.
class AppShellScaffold extends ConsumerWidget {
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
        ShellDestination.train => FluiGlyph.microphone,
        // The word-entry glyph: a dictionary entry, which is what the
        // repertoire is.
        ShellDestination.words => FluiGlyph.wordOfTheDay,
        ShellDestination.progress => FluiGlyph.streak,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final micController = ref.watch(micControllerProvider);
    final items = [
      for (final destination in ShellDestination.values)
        (
          glyphOf(destination),
          switch (destination) {
            ShellDestination.today => l10n.navToday,
            ShellDestination.train => l10n.navTrain,
            ShellDestination.words => l10n.navWords,
            ShellDestination.progress => l10n.navProgress,
          },
        ),
    ];
    // Progress stays the LAST destination, so this index works regardless.
    final progressIndex = items.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < FluiBreakpoints.rail) {
          return Scaffold(
            backgroundColor: FluiColors.paper,
            body: child,
            bottomNavigationBar: FluiBottomBar(
              items: [
                for (final (index, entry) in items.indexed)
                  if (index == progressIndex)
                    (entry.$1, l10n.navProgressShort)
                  else
                    entry,
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              progressIndex: progressIndex,
              micController: micController,
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
                    // Null only for the brief instant around sign-out/
                    // sign-in (mirrors `FluiBottomBar`'s own guard).
                    child: switch (micController) {
                      final controller? => MicButton(controller: controller),
                      null when extended => const FluiLogo(symbolSize: 32),
                      null => const FluiSymbol(size: 32, semanticLabel: 'flui'),
                    },
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
