import 'package:flui/app/pages/not_found_page.dart';
import 'package:flui/app/pages/splash_page.dart';
import 'package:flui/app/router/app_redirect.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/app/router/flui_transitions.dart';
import 'package:flui/app/shell/app_shell.dart';
import 'package:flui/features/auth/presentation/pages/login_page.dart';
import 'package:flui/features/auth/presentation/pages/password_reset_page.dart';
import 'package:flui/features/auth/presentation/pages/register_page.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/daily/presentation/session_page.dart';
import 'package:flui/features/daily/presentation/time_budget_page.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/onboarding/presentation/intro_page.dart';
import 'package:flui/features/onboarding/presentation/welcome_page.dart';
import 'package:flui/features/profile/presentation/progress_page.dart';
import 'package:flui/features/speaking/presentation/speaking_challenge_page.dart';
import 'package:flui/features/subscription/presentation/pages/checkout_return_page.dart';
import 'package:flui/features/subscription/presentation/pages/paywall_page.dart';
import 'package:flui/features/subscription/presentation/pages/plan_preview_page.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/vocabulary/presentation/word_detail_page.dart';
import 'package:flui/features/vocabulary/presentation/words_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Where the router starts when the platform gives no location (mobile,
/// tests). On web the browser URL wins.
@Riverpod(keepAlive: true)
String routerInitialLocation(Ref ref) => AppRoutes.today;

@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final refresh = _RouterRefresh();
  // Listening also keeps both providers active for the router's lifetime.
  ref
    ..listen(authStatusProvider, (_, _) => refresh.notify())
    ..listen(accessGateProvider, (_, _) => refresh.notify())
    ..listen(dailyGateProvider, (_, _) => refresh.notify());

  // Created per router so tests can build many routers.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: ref.watch(routerInitialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      auth: ref.read(authStatusProvider),
      access: ref.read(accessGateProvider),
      daily: ref.read(dailyGateProvider),
      location: state.uri,
    ),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: _routes(rootKey),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}

List<RouteBase> _routes(GlobalKey<NavigatorState> rootKey) => [
  GoRoute(path: AppRoutes.root, builder: (_, _) => const SplashPage()),
  GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
  GoRoute(path: AppRoutes.welcome, builder: (_, _) => const WelcomePage()),
  // The onboarding chain shares a horizontal axis: same flow, next step.
  GoRoute(
    path: AppRoutes.intro,
    pageBuilder: (_, state) =>
        FluiTransitions.sharedAxisX(const IntroPage(), key: state.pageKey),
  ),
  GoRoute(
    path: AppRoutes.plan,
    pageBuilder: (_, state) => FluiTransitions.sharedAxisX(
      const PlanPreviewPage(),
      key: state.pageKey,
    ),
  ),
  GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
  GoRoute(
    path: AppRoutes.register,
    pageBuilder: (_, state) =>
        FluiTransitions.sharedAxisX(const RegisterPage(), key: state.pageKey),
  ),
  GoRoute(
    path: AppRoutes.resetPassword,
    builder: (_, _) => const PasswordResetPage(),
  ),
  GoRoute(path: AppRoutes.paywall, builder: (_, _) => const PaywallPage()),
  GoRoute(
    path: AppRoutes.checkoutReturn,
    builder: (_, _) => const CheckoutReturnPage(),
  ),
  GoRoute(
    path: AppRoutes.session,
    parentNavigatorKey: rootKey,
    // A different place, not the next step: the session scales in.
    pageBuilder: (_, state) => FluiTransitions.sharedAxisZ(
      SessionPage(mode: _modeOf(state.uri)),
      key: state.pageKey,
    ),
  ),
  StatefulShellRoute.indexedStack(
    parentNavigatorKey: rootKey,
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.today,
            builder: (_, _) => const TodayPage(),
            routes: [
              GoRoute(
                path: 'time',
                parentNavigatorKey: rootKey,
                builder: (_, _) => const TimeBudgetPage(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.words,
            builder: (_, _) => const WordsPage(),
            routes: [
              GoRoute(
                path: ':wordId',
                builder: (_, state) =>
                    WordDetailPage(wordId: state.pathParameters['wordId']!),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          // Habla: selecting the tab always lands on the challenge's own
          // "ready" phase. Starting a challenge goes to `.../live`, a
          // full-screen take-over on the root navigator, same as
          // `/today/time` above — the shell chrome disappears exactly like
          // it does entering `/session` from `/today`.
          GoRoute(
            path: AppRoutes.speakingChallenge,
            builder: (_, _) => const SpeakingTabPage(),
            routes: [
              GoRoute(
                path: 'live',
                parentNavigatorKey: rootKey,
                pageBuilder: (_, state) => FluiTransitions.sharedAxisZ(
                  const SpeakingChallengePage(autoStart: true),
                  key: state.pageKey,
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.progress,
            builder: (_, _) => const ProgressPage(),
          ),
        ],
      ),
    ],
  ),
];

SessionMode _modeOf(Uri uri) {
  final mode = uri.queryParameters['mode'];
  return SessionMode.values.where((value) => value.name == mode).firstOrNull ??
      SessionMode.daily;
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
