import 'package:flui/app/flui_app.dart';
import 'package:flui/app/licenses.dart';
import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/config/app_config.dart';
import 'package:flui/core/config/app_config_provider.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/supabase/supabase_client_provider.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/data/supabase_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/data/supabase_daily_session_repository.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/exercises/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/exercises/data/supabase_exercise_attempt_repository.dart';
import 'package:flui/features/exercises/presentation/providers/exercise_providers.dart';
import 'package:flui/features/onboarding/data/preferences_onboarding_store.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/profile/data/fake_streak_repair_repository.dart';
import 'package:flui/features/profile/data/supabase_streak_repair_repository.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/subscription/data/fake_checkout_launcher.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/data/supabase_subscription_repository.dart';
import 'package:flui/features/subscription/data/url_checkout_launcher.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/themes/data/fake_theme_repository.dart';
import 'package:flui/features/themes/data/supabase_theme_repository.dart';
import 'package:flui/features/themes/presentation/providers/theme_providers.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/data/supabase_content_repository.dart';
import 'package:flui/features/vocabulary/data/supabase_word_progress_repository.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Composition root: picks the backend and wires repositories into Riverpod.
Future<void> bootstrap(Result<AppConfig> configResult) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path URLs (no #) so Whop can redirect to /checkout/return.
  usePathUrlStrategy();
  registerBundledLicenses();

  switch (configResult) {
    case Err(:final failure):
      runApp(ProviderScope(child: ConfigErrorApp(failure: failure)));
    case Ok(value: final config):
      final overrides = switch (config.backend) {
        Backend.fake => fakeBackendOverrides(config: config),
        Backend.supabase => await supabaseBackendOverrides(config),
      };
      runApp(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            ...overrides,
          ],
          // Failures are typed and shown to the user; no silent retries.
          retry: (_, _) => null,
          child: const FluiApp(),
        ),
      );
  }
}

/// In-memory backend (`BACKEND=fake`): every flow with the seed words, no
/// network.
List<Override> fakeBackendOverrides({
  AppConfig config = const AppConfig(backend: Backend.fake),
  Duration latency = const Duration(milliseconds: 350),
}) {
  const devUser = AppUser(
    id: 'local-developer',
    email: 'dev@flui.local',
    displayName: 'Modo desarrollo',
  );
  final auth = FakeAuthRepository(
    initialUser: config.devBypassAuth ? devUser : null,
    latency: latency,
  );
  String? currentUserId() => auth.currentUser?.id;
  final subscriptions = FakeSubscriptionRepository(
    clock: const SystemClock(),
    currentUserId: currentUserId,
    latency: latency,
  );
  final sessions = FakeDailySessionRepository(currentUserId: currentUserId);
  if (config.devBypassAuth) {
    subscriptions.grantAccess(const AccessStatus(hasAccess: true));
    sessions.seedSession(
      DailySession(
        localDate: LocalDate.fromDateTime(DateTime.now()),
        minutes: 5,
      ),
    );
  }
  return [
    authRepositoryProvider.overrideWithValue(auth),
    onboardingStoreProvider.overrideWithValue(InMemoryOnboardingStore()),
    subscriptionRepositoryProvider.overrideWithValue(subscriptions),
    contentRepositoryProvider.overrideWithValue(
      FakeContentRepository(latency: latency),
    ),
    themeRepositoryProvider.overrideWithValue(
      FakeThemeRepository(latency: latency),
    ),
    wordProgressRepositoryProvider.overrideWithValue(
      FakeWordProgressRepository(currentUserId: currentUserId),
    ),
    exerciseAttemptRepositoryProvider.overrideWith(
      (ref) => FakeExerciseAttemptRepository(
        currentUserId: currentUserId,
        now: ref.read(clockProvider).now,
      ),
    ),
    dailySessionRepositoryProvider.overrideWithValue(sessions),
    streakRepairRepositoryProvider.overrideWithValue(
      FakeStreakRepairRepository(currentUserId: currentUserId),
    ),
    checkoutLauncherProvider.overrideWith(
      (ref) => FakeCheckoutLauncher(
        subscriptions: subscriptions,
        onReturn: () => ref.read(goRouterProvider).go(AppRoutes.checkoutReturn),
      ),
    ),
  ];
}

/// Supabase backend. `Supabase.initialize` restores a persisted session
/// before the first frame, so reloads keep the user signed in.
Future<List<Override>> supabaseBackendOverrides(AppConfig config) async {
  await Supabase.initialize(
    url: config.supabaseUrl.toString(),
    publishableKey: config.supabaseAnonKey,
  );
  final client = Supabase.instance.client;
  String? currentUserId() => client.auth.currentUser?.id;
  return [
    supabaseClientProvider.overrideWithValue(client),
    onboardingStoreProvider.overrideWithValue(
      PreferencesOnboardingStore(SharedPreferencesAsync()),
    ),
    authRepositoryProvider.overrideWithValue(
      SupabaseAuthRepository(client.auth, appUrl: config.appUrl),
    ),
    subscriptionRepositoryProvider.overrideWithValue(
      SupabaseSubscriptionRepository(client),
    ),
    checkoutLauncherProvider.overrideWithValue(const UrlCheckoutLauncher()),
    contentRepositoryProvider.overrideWithValue(
      SupabaseContentRepository(client),
    ),
    themeRepositoryProvider.overrideWithValue(SupabaseThemeRepository(client)),
    wordProgressRepositoryProvider.overrideWithValue(
      SupabaseWordProgressRepository(client, currentUserId: currentUserId),
    ),
    exerciseAttemptRepositoryProvider.overrideWithValue(
      SupabaseExerciseAttemptRepository(client, currentUserId: currentUserId),
    ),
    dailySessionRepositoryProvider.overrideWithValue(
      SupabaseDailySessionRepository(client, currentUserId: currentUserId),
    ),
    streakRepairRepositoryProvider.overrideWithValue(
      SupabaseStreakRepairRepository(client, currentUserId: currentUserId),
    ),
  ];
}

/// Developer-facing screen for a broken build configuration.
class ConfigErrorApp extends StatelessWidget {
  const new({required this.failure, super.key});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final message = failure is ConfigFailure
        ? (failure as ConfigFailure).message
        : failure.toString();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No pudimos iniciar flui.\n\n$message\n\n'
              'flutter run --dart-define-from-file=config/fake.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
