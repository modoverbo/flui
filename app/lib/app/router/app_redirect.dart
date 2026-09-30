import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/auth/domain/auth_status.dart';
import 'package:flui/features/daily/domain/daily_gate.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_gate.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';

/// Pure routing guard: where [location] should go for the given state.
///
/// Returns `null` to stay. While the state is unknown the user waits on the
/// splash, which remembers the requested location in `?from=` so deep links
/// such as `/checkout/return` survive a full page reload.
///
/// With access, the app routes ([AppRoutes.needsDailyBudget]) first ask for
/// today's time budget when [daily] has no session for today.
///
/// [diagnosis] gates the mandatory diagnosis (design part-3 §11, D16).
String? appRedirect({
  required AuthStatus auth,
  required AccessGate access,
  required DailyGate daily,
  required Uri location,
  DiagnosisGate diagnosis = DiagnosisGate.notRequired,
}) {
  final atSplash = location.path == AppRoutes.splash;
  final target = atSplash ? _rememberedLocation(location) : location;
  final destination = _destinationFor(auth, access, daily, target, diagnosis);

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
  DiagnosisGate diagnosis,
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
          // 1. Checkout return goes to diagnosis first when it's required,
          //    else the ordinary daily time budget ask.
          if (path == AppRoutes.checkoutReturn) {
            return diagnosis == DiagnosisGate.required
                ? AppRoutes.diagnosis
                : AppRoutes.timeBudget;
          }
          // 2. Old deep links to retired tabs still win, incl. Habla ->
          //    ENTRENAR (U16).
          if (AppRoutes.retiredRoutes[path] case final moved?) return moved;
          // 3. Unknown/error diagnosis waits, exactly like AccessGate.
          if (diagnosis == DiagnosisGate.unknown ||
              diagnosis == DiagnosisGate.error) {
            return null;
          }
          // 4. Required: every path except the diagnosis routes themselves
          //    forces the user into diagnosis before anything else.
          if (diagnosis == DiagnosisGate.required &&
              !AppRoutes.diagnosisRoutes.contains(path)) {
            return AppRoutes.diagnosis;
          }
          // 5. Completed: `/diagnosis/live` is done unless explicitly
          //    retaking. The intro page stays reachable (U14c's retake
          //    entry point).
          if (diagnosis == DiagnosisGate.completed &&
              path == AppRoutes.diagnosisLive &&
              target.queryParameters['retake'] != '1') {
            return AppRoutes.today;
          }
          // 6. Daily budget check, last.
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
