import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [page] at [location] with stub pages for other routes, so tests can
/// assert navigation by looking for `route:<path>` texts.
///
/// [initialLocation] defaults to [location]. Passing one of [otherRoutes]
/// instead lets a test start on a stub screen and then `router.push(
/// location)` to bring up the real [page] on top of it — the one-page-deep
/// setup a back-button test needs to exercise a true `pop()`, without ever
/// mounting two instances of [page] at once.
Future<GoRouter> pumpRoutedPage(
  WidgetTester tester, {
  required String location,
  required Widget page,
  List<String> otherRoutes = const [],
  List<Override> overrides = const [],
  Size? surfaceSize,
  String? initialLocation,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  final router = GoRouter(
    initialLocation: initialLocation ?? location,
    routes: [
      GoRoute(path: location, builder: (_, _) => page),
      for (final route in otherRoutes)
        GoRoute(
          path: route,
          builder: (_, _) => Scaffold(body: Text('route:$route')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp.router(
        theme: FluiTheme.light(),
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  return router;
}
