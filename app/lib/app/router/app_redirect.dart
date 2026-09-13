import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/domain/auth_status.dart';
import 'package:flui/features/daily/domain/daily_gate.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';

/// Pure routing guard: where [location] should go for the given state.
///
/// Returns `null` to stay. While the state is unknown the user waits on the
/// splash, which remembers the requested location in `?from=` so deep links
/// such as `/checkout/return` survive a full page reload.
///
/// With access, the app routes ([AppRoutes.needsDailyBudget]) first ask for
/// today's time budget when [daily] has no session for today.
String? appRedirect({
  required AuthStatus auth,
  required AccessGate access,
  required DailyGate daily,
  required Uri location,
}) {
  final atSplash = location.path == AppRoutes.splash;
  final target = atSplash ? _rememberedLocation(location) : location;
  final destination = _destinationFor(auth, access, daily, target);

  if (destination == null) {
    // State still unknown: wait on the splash.
    return atSplash ? null : AppRoutes.splashFrom(target);
  }
  return destination == location.toString() ? null : destination;
}

/// The final destination for [target], or `null` while the state is unknown.
String? _destinationFor(
  AuthStatus auth,
  AccessGate access,
  DailyGate daily,
  Uri target,
) {
  final path = target.path;
  switch (auth) {
    case AuthStatus.unknown:
      return null;
    case AuthStatus.signedOut:
      if (AppRoutes.publicRoutes.contains(path)) return target.toString();
      if (path == AppRoutes.checkoutReturn) return AppRoutes.login;
      return AppRoutes.welcome;
    case AuthStatus.signedIn:
      switch (access) {
        case AccessGate.unknown:
        case AccessGate.error:
          return null;
        case AccessGate.denied:
          return AppRoutes.accessFreeRoutes.contains(path)
              ? target.toString()
              : AppRoutes.paywall;
        case AccessGate.granted:
          if (path == AppRoutes.checkoutReturn) return AppRoutes.timeBudget;
          final resolved =
              path == AppRoutes.root ||
                  path == AppRoutes.splash ||
                  path == AppRoutes.paywall ||
                  AppRoutes.publicRoutes.contains(path)
              ? Uri(path: AppRoutes.today)
              : target;
          if (!AppRoutes.needsDailyBudget(resolved.path)) {
            return resolved.toString();
          }
          return switch (daily) {
            DailyGate.unknown => null,
            DailyGate.needsBudget => AppRoutes.timeBudget,
            DailyGate.planned || DailyGate.unavailable => resolved.toString(),
          };
      }
  }
}

/// Reads `?from=` from the splash location, accepting only in-app paths.
Uri _rememberedLocation(Uri splash) {
  final fallback = Uri(path: AppRoutes.root);
  final raw = splash.queryParameters['from'];
  if (raw == null || !raw.startsWith('/') || raw.startsWith('//')) {
    return fallback;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.path == AppRoutes.splash) {
    return fallback;
  }
  return uri;
}
