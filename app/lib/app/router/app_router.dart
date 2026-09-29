import 'package:flui/app/pages/not_found_page.dart';
import 'package:flui/app/pages/splash_page.dart';
import 'package:flui/app/router/app_redirect.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/app/router/flui_transitions.dart';
import 'package:flui/app/shell/app_shell.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/mic/presentation/mic_layer_scope.dart';
import 'package:flui/features/auth/presentation/pages/login_page.dart';
import 'package:flui/features/auth/presentation/pages/password_reset_page.dart';
import 'package:flui/features/auth/presentation/pages/register_page.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/presentation/controllers/session_controller.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/daily/presentation/session_page.dart';
import 'package:flui/features/daily/presentation/time_budget_page.dart';
import 'package:flui/features/daily/presentation/today_page.dart';
import 'package:flui/features/daily/presentation/today_train_page.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_gate.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_intro_page.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_page.dart';
import 'package:flui/features/diagnosis/presentation/diagnosis_result_page.dart';
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
import 'package:flui/features/vocabulary/presentation/word_speak_page.dart';
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
    ..listen(dailyGateProvider, (_, _) => refresh.notify())
    ..listen(diagnosisGateProvider, (_, _) => refresh.notify());

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
      diagnosis: ref.read(diagnosisGateProvider),
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
  // The mandatory diagnosis (design part-3 §11, D16, U14a): reachable only
  // while speakingGym is on — flag off, these paths are unregistered and
  // hit NotFoundPage, matching "diagnosis routes must be unreachable".
  // Root-navigator, outside the shell: the gate blocks every tab, so there
  // is no chrome to keep, unlike ENTRENAR's own in-branch loop screens.
  if (speakingGym) ..._diagnosisRoutes(rootKey),
  StatefulShellRoute(
    parentNavigatorKey: rootKey,
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
    // The default `StatefulShellRoute.indexedStack` container, spelled out
    // explicitly (U16) so each branch can be wrapped with `MicLayerScope`
    // (U23c, design §19.7) without changing the underlying behavior:
    // still one `IndexedStack` keeping every branch's navigator alive.
    navigatorContainerBuilder: (context, navigationShell, children) =>
        IndexedStack(
          index: navigationShell.currentIndex,
          children: [
            for (final (index, child) in children.indexed)
              MicLayerScope(branch: index, child: child),
          ],
        ),
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
  _todayBranch(rootKey, speakingGym: true),
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
  _wordsBranch(speakingGym: true),
  _progressBranch(),
];

StatefulShellBranch _todayBranch(
  GlobalKey<NavigatorState> rootKey, {
  bool speakingGym = false,
}) => StatefulShellBranch(
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
        // HOY's own loop (U15a): a branch child, not a root-navigator
        // take-over (design D30, matches ENTRENAR's `/train/:mode`) —
        // only reachable while `speakingGym` is on.
        if (speakingGym)
          GoRoute(path: 'train', builder: (_, _) => const TodayTrainPage()),
      ],
    ),
  ],
);

StatefulShellBranch _wordsBranch({bool speakingGym = false}) =>
    StatefulShellBranch(
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
              routes: [
                // PALABRAS' own spoken-use loop (U17): a branch child of
                // the word detail, not a root-navigator take-over (design
                // D30, matches ENTRENAR's `/train/:mode`) — only reachable
                // while `speakingGym` is on.
                if (speakingGym)
                  GoRoute(
                    path: 'speak',
                    builder: (context, state) =>
                        WordSpeakPage(wordId: state.pathParameters['wordId']!),
                  ),
              ],
            ),
          ],
        ),
      ],
    );

List<RouteBase> _diagnosisRoutes(GlobalKey<NavigatorState> rootKey) => [
  GoRoute(
    path: AppRoutes.diagnosis,
    parentNavigatorKey: rootKey,
    builder: (_, _) => const DiagnosisIntroPage(),
  ),
  GoRoute(
    path: AppRoutes.diagnosisLive,
    parentNavigatorKey: rootKey,
    builder: (_, _) => const DiagnosisPage(),
  ),
  GoRoute(
    path: AppRoutes.diagnosisResult,
    parentNavigatorKey: rootKey,
    builder: (_, _) => const DiagnosisResultPage(),
  ),
];

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
