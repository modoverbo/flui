import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart';

/// Order of the shell branches. Keep in sync with `app_router.dart`.
///
/// Three tabs, not five: "Practica" became the "Repaso extra" action on Hoy
/// and "En contexto" became a section of the word detail, because both were
/// places the user had to remember to visit.
enum ShellDestination { today, words, progress }

/// Navigation chrome: bottom bar on phones, side rail on wide screens.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      for (final destination in ShellDestination.values)
        switch (destination) {
          ShellDestination.today => (LucideIcons.sun, l10n.navToday),
          ShellDestination.words => (LucideIcons.whole_word, l10n.navWords),
          ShellDestination.progress => (
            LucideIcons.chart_line,
            l10n.navProgress,
          ),
        },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < FluiBreakpoints.rail) {
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final (icon, label) in items)
                  NavigationDestination(icon: Icon(icon), label: label),
              ],
            ),
          );
        }

        final extended = width >= FluiBreakpoints.extendedRail;
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  extended: extended,
                  minExtendedWidth: 220,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
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
                    for (final (icon, label) in items)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        label: Text(label),
                        padding: const EdgeInsets.symmetric(
                          vertical: FluiSpacing.xxs,
                        ),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, color: FluiColors.outline),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
