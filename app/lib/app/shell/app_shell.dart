import 'package:flui/app/shell/app_shell_scaffold.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Connects the go_router shell to the navigation chrome.
///
/// Also keeps `MicTargetRegistry.setActiveBranch` (design §19.4/§19.7) in
/// sync with the shell's current branch on every rebuild — which branch's
/// stack the shell's single mic resolves against always matches the
/// visible tab, including on deep links and programmatic navigation, not
/// only on an explicit tab tap.
class AppShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
        .read(micTargetRegistryProvider)
        .setActiveBranch(navigationShell.currentIndex);
    return AppShellScaffold(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      child: navigationShell,
    );
  }
}
