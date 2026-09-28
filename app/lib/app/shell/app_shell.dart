import 'package:flui/app/shell/app_shell_scaffold.dart';
import 'package:flui/app/shell/mic_navigation_binding.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/presentation/mic_notice_host.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_panel_host.dart';
import 'package:flui/features/training/presentation/quick/quick_practice_target.dart';
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
///
/// While `speakingGym` is on (D32), also owns the app-lifetime
/// `MicNavigationBinding` (U23d, design §19.6), wraps the shell in a
/// `MicNoticeHost`, installs `QuickPracticeTarget` as the registry's
/// fallback and wraps the shell in a `QuickPracticePanelHost` (U23e,
/// design §19.13) — all entirely absent from the tree while the flag is
/// off, so the flag-off shell has zero mic-notice/navigation-binding/
/// quick-practice side effects (production safety: every push
/// auto-deploys the web app).
class AppShell extends ConsumerStatefulWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  MicNavigationBinding? _binding;
  bool _boundOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_boundOnce) return;
    _boundOnce = true;
    if (!ref.read(speakingGymEnabledProvider)) return;
    _binding = MicNavigationBinding(
      registry: ref.read(micTargetRegistryProvider),
      controllerOf: () => ref.read(micControllerProvider),
      routerSource: GoRouterLocationSource(GoRouter.of(context)),
    );
    // Overrides U23b's ExplainedFallbackTarget once, for the shell's
    // lifetime (design §19.13, decision #450.3).
    ref
        .read(micTargetRegistryProvider)
        .setFallback(ref.read(quickPracticeTargetProvider));
  }

  @override
  void dispose() {
    _binding?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
        .read(micTargetRegistryProvider)
        .setActiveBranch(widget.navigationShell.currentIndex);
    final speakingGym = ref.watch(speakingGymEnabledProvider);
    // Only watched when the flag is on: the flag-off shell never touches
    // the mic session at all (D32), matching `AppShellScaffold`'s own
    // guard for the same provider.
    final micController = speakingGym ? ref.watch(micControllerProvider) : null;
    final quickPracticeTarget = speakingGym
        ? ref.watch(quickPracticeTargetProvider)
        : null;
    final scaffold = AppShellScaffold(
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: (index) => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      ),
      child: widget.navigationShell,
    );
    if (!speakingGym) return scaffold;
    return MicNoticeHost(
      controller: micController,
      child: QuickPracticePanelHost(
        target: quickPracticeTarget,
        child: scaffold,
      ),
    );
  }
}
