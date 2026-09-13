import 'dart:async';

import 'package:flui/app/router/app_router.dart';
import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class FluiApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: FluiTheme.light(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        // material_ui's list also includes the Cupertino and widgets delegates.
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: ref.watch(goRouterProvider),
      builder: (context, child) => _AccessRefreshOnResume(child: child!),
    );
  }
}

/// Re-checks `my_access()` when the app comes back to the foreground, so an
/// ended subscription returns the user to the paywall.
class _AccessRefreshOnResume extends ConsumerStatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  ConsumerState<_AccessRefreshOnResume> createState() =>
      _AccessRefreshOnResumeState();
}

class _AccessRefreshOnResumeState
    extends ConsumerState<_AccessRefreshOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onResume: _refreshAccess);
  }

  void _refreshAccess() {
    final userId = ref.read(authUserProvider).value?.id;
    if (userId == null) return;
    unawaited(
      ref.read(accessStatusControllerProvider(userId).notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
