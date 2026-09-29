import 'dart:async';

import 'package:flui/app/flui_app.dart';
import 'package:flui/app/router/app_router.dart';
import 'package:flui/app/router/app_routes.dart';
import 'package:flui/bootstrap.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/presentation/providers/exercise_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The whole app on the in-memory backend from `bootstrap.dart`, with an
/// instant clock so polling never waits in real time.
final class AppHarness {
  new({
    AppUser? signedInAs,
    AccessStatus? access,
    List<Override> overrides = const [],
  }) : _initialUser = signedInAs,
       _initialAccess = access,
       _extraOverrides = overrides;

  /// The same fake wiring as `BACKEND=fake`, without artificial latency.
  final List<Override> backend = fakeBackendOverrides(latency: Duration.zero);
  final clock = FixedClock(DateTime(2026, 9, 13, 10));
  final AppUser? _initialUser;
  final AccessStatus? _initialAccess;

  /// Extra overrides a test needs (e.g. `speakingGymEnabledProvider`),
  /// applied AFTER [backend] so they can override any of it too.
  final List<Override> _extraOverrides;
  late ProviderContainer container;

  FakeAuthRepository get auth =>
      container.read(authRepositoryProvider) as FakeAuthRepository;

  FakeSubscriptionRepository get subscriptions =>
      container.read(subscriptionRepositoryProvider)
          as FakeSubscriptionRepository;

  FakeDailySessionRepository get dailySessions =>
      container.read(dailySessionRepositoryProvider)
          as FakeDailySessionRepository;

  FakeWordProgressRepository get wordProgress =>
      container.read(wordProgressRepositoryProvider)
          as FakeWordProgressRepository;

  FakeExerciseAttemptRepository get attempts =>
      container.read(exerciseAttemptRepositoryProvider)
          as FakeExerciseAttemptRepository;

  FakeSkillProfileRepository get skillProfiles =>
      container.read(skillProfileRepositoryProvider)
          as FakeSkillProfileRepository;

  FakeSpeakingAttemptRepository get speakingAttempts =>
      container.read(speakingAttemptRepositoryProvider)
          as FakeSpeakingAttemptRepository;

  /// The shared `speechAnalysisRepositoryProvider` fake (U17b): tests
  /// control the NEXT `transcribe()` call's text via
  /// `speech.nextTranscribeText` instead of re-overriding the provider,
  /// which `fakeBackendOverrides` already declares once.
  FakeSpeechAnalysisRepository get speech =>
      container.read(speechAnalysisRepositoryProvider)
          as FakeSpeechAnalysisRepository;

  /// Saves today's time budget so the app skips "¿Cuánto tiempo tienes hoy?".
  Future<void> planToday({int minutes = 10}) async {
    await dailySessions.saveSession(
      DailySession(localDate: clock.localToday(), minutes: minutes),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    String initialLocation = AppRoutes.today,
    Size size = const Size(400, 860),
    FutureOr<void> Function(AppHarness harness)? arrange,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Reduce motion: the loading waves stay still so pumpAndSettle ends.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    container = ProviderContainer(
      overrides: [
        ...backend,
        clockProvider.overrideWithValue(clock),
        sleepProvider.overrideWithValue(
          (duration) async => clock.advance(duration),
        ),
        routerInitialLocationProvider.overrideWithValue(initialLocation),
        ..._extraOverrides,
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    final user = _initialUser;
    if (user != null) {
      await auth.signUp(
        displayName: user.displayName ?? 'Ana',
        email: user.email,
        password: 'secreta123',
      );
      final access = _initialAccess;
      if (access != null) subscriptions.grantAccess(access);
    }
    await arrange?.call(this);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FluiApp()),
    );
    await tester.pumpAndSettle();
  }
}
