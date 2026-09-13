import 'package:flui/app/shell/app_shell_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Connects the go_router shell to the navigation chrome.
class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
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
