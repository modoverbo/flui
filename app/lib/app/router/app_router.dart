import 'package:flui/app/pages/not_found_page.dart';
import 'package:flui/app/pages/splash_page.dart';
import 'package:flui/app/router/app_redirect.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/app/router/flui_transitions.dart';
import 'package:flui/app/shell/app_shell.dart';
import 'package:flui/core/config/feature_flags.dart';
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
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flui/features/training/presentation/training_lab_page.dart';
import 'package:flui/features/vocabulary/presentation/category_catalog_page.dart';
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

  // The router is built once at startup (design D17): no runtime toggling,
  // so a plain read (not watch) is enough here.
  final speakingGym = ref.read(speakingGymEnabledProvider);

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
      speakingGym: speakingGym,
    ),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: _routes(rootKey, speakingGym: speakingGym),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}

List<RouteBase> _routes(
  GlobalKey<NavigatorState> rootKey, {
  required bool speakingGym,
}) => [
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
  StatefulShellRoute(
    parentNavigatorKey: rootKey,
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
    // The default `StatefulShellRoute.indexedStack` container, spelled out
    // explicitly (U16) so a later unit (U23c) can wrap it with
    // `MicLayerScope` per branch without changing this behavior.
    navigatorContainerBuilder: (context, navigationShell, children) =>
        IndexedStack(index: navigationShell.currentIndex, children: children),
    branches: speakingGym ? _gymBranches(rootKey) : _originalBranches(rootKey),
  ),
];

/// Shell branches while `speakingGym` is OFF (the default, unchanged since
/// before U16): Hoy, Palabras, Habla, Progreso — matches
/// `app_shell_scaffold.dart`'s `ShellDestination` order exactly.
List<StatefulShellBranch> _originalBranches(
  GlobalKey<NavigatorState> rootKey,
) => [
  _todayBranch(rootKey),
  _wordsBranch(),
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
              const SpeakingChallengePage(),
              key: state.pageKey,
            ),
          ),
        ],
      ),
    ],
  ),
  _progressBranch(),
];

/// Shell branches while `speakingGym` is ON (U16): Hoy, ENTRENAR, Palabras,
/// Progreso — matches `app_shell_scaffold.dart`'s `GymShellDestination`
/// order exactly. ENTRENAR replaces Habla's slot; `/speaking/challenge`
/// deep links redirect to it via `AppRoutes.gymRetiredRoutes`.
List<StatefulShellBranch> _gymBranches(GlobalKey<NavigatorState> rootKey) => [
  _todayBranch(rootKey),
  StatefulShellBranch(
    routes: [
      // ENTRENAR (U16, replacing the Habla/speaking-challenge tab):
      // selecting the tab lands on the mode picker; a mode's own loop is
      // a branch child, not a root-navigator take-over (design D30) —
      // unlike Habla's `/speaking/challenge/live`.
      GoRoute(
        path: AppRoutes.train,
        builder: (_, _) => const TrainingLabPage(),
        routes: [
          GoRoute(
            path: ':mode',
            builder: (context, state) {
              final mode = _trainingModeOf(state.pathParameters['mode']);
              return mode == null
                  ? const NotFoundPage()
                  : TrainingLabModePage(mode: mode);
            },
          ),
        ],
      ),
    ],
  ),
  _wordsBranch(),
  _progressBranch(),
];

StatefulShellBranch _todayBranch(
  GlobalKey<NavigatorState> rootKey,
) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: AppRoutes.today,
      builder: (_, _) => const TodayPage(),
      routes: [
        GoRoute(
          path: 'categories/:family',
          parentNavigatorKey: rootKey,
          builder: (_, state) => CategoryCatalogPage(
            familySlug: state.pathParameters['family']!,
            initialThemeId: state.uri.queryParameters['theme'],
            initialScrollOffset:
                double.tryParse(state.uri.queryParameters['offset'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: 'time',
          parentNavigatorKey: rootKey,
          builder: (_, _) => const TimeBudgetPage(),
        ),
      ],
    ),
  ],
);

StatefulShellBranch _wordsBranch() => StatefulShellBranch(
  routes: [
    GoRoute(
      path: AppRoutes.words,
      builder: (_, _) => const WordsPage(),
      routes: [
        GoRoute(
          path: ':wordId',
          builder: (context, state) => _WordDetailRoute(
            wordId: state.pathParameters['wordId']!,
            returnLocation: state.uri.queryParameters['returnTo'],
          ),
        ),
      ],
    ),
  ],
);

StatefulShellBranch _progressBranch() => StatefulShellBranch(
  routes: [
    GoRoute(path: AppRoutes.progress, builder: (_, _) => const ProgressPage()),
  ],
);

TrainingMode? _trainingModeOf(String? raw) =>
    TrainingMode.values.where((mode) => mode.name == raw).firstOrNull;

/// A catalog entry is reached from the category flow with an explicit return
/// location because GoRouter switches shell branches for `/words/:wordId`.
class _WordDetailRoute extends StatelessWidget {
  const new({required this.wordId, this.returnLocation});

  final String wordId;
  final String? returnLocation;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: returnLocation == null,
    onPopInvokedWithResult: (didPop, _) {
      final destination = returnLocation;
      if (!didPop && destination != null) context.go(destination);
    },
    child: WordDetailPage(wordId: wordId),
  );
}

SessionMode _modeOf(Uri uri) {
  final mode = uri.queryParameters['mode'];
  return SessionMode.values.where((value) => value.name == mode).firstOrNull ??
      SessionMode.daily;
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
