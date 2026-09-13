import 'package:flui/app/pages/not_found_page.dart';
import 'package:flui/app/pages/splash_page.dart';
import 'package:flui/app/router/app_redirect.dart';
import 'package:flui/app/router/app_routes.dart';
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
import 'package:flui/features/exercises/presentation/practice_page.dart';
import 'package:flui/features/onboarding/presentation/intro_page.dart';
import 'package:flui/features/onboarding/presentation/welcome_page.dart';
import 'package:flui/features/profile/presentation/progress_page.dart';
import 'package:flui/features/reading/presentation/reading_page.dart';
import 'package:flui/features/subscription/presentation/pages/checkout_return_page.dart';
import 'package:flui/features/subscription/presentation/pages/paywall_page.dart';
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
  GoRoute(path: AppRoutes.intro, builder: (_, _) => const IntroPage()),
  GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
  GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterPage()),
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
    builder: (_, state) => SessionPage(
      mode: state.uri.queryParameters['mode'] == SessionMode.review.name
          ? SessionMode.review
          : SessionMode.daily,
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
          GoRoute(
            path: AppRoutes.practice,
            builder: (_, _) => const PracticePage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: AppRoutes.reading,
            builder: (_, _) => const ReadingPage(),
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

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
