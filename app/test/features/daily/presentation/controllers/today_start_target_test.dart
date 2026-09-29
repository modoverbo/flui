import 'dart:async';
import 'dart:typed_data';

import 'package:flui/core/audio/audio_providers.dart';
import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/audio/speech_recorder.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/mic/mic_controller.dart';
import 'package:flui/core/mic/mic_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/controllers/today_start_target.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_fakes.dart';
import '../../../../helpers/test_container.dart';

/// A recorder whose `start()` call is observable — the whole point of the
/// U15a review fix is that `TodayStartTarget` never triggers this: the mic
/// on HOY only plans/navigates, it never records directly.
final class _WatchedSpeechRecorder implements SpeechRecorder {
  new();

  int startCalls = 0;

  @override
  Stream<double> get amplitude => const Stream.empty();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<Uint8List> stop() async => Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late LearningFakes fakes;
  late _WatchedSpeechRecorder recorder;

  setUp(() {
    fakes = LearningFakes(speakingGym: true);
    recorder = _WatchedSpeechRecorder();
  });
  tearDown(() => fakes.dispose());

  ProviderContainer build() {
    final subscriptions =
        FakeSubscriptionRepository(
          clock: fakes.clock,
          currentUserId: () => fakes.auth.currentUser?.id,
        )..grantAccess(
          const AccessStatus(
            hasAccess: true,
            entitlementStatus: EntitlementStatus.trialing,
          ),
        );
    final container = createTestContainer(
      overrides: [
        ...fakes.overrides,
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
        speechRecorderFactoryProvider.overrideWithValue(() => recorder),
      ],
    );
    // Keeps the autoDispose chains this target reads (`authUserProvider`
    // via `PlanToday`, `todayOverviewProvider`, `micControllerProvider`)
    // alive across the async gaps below — in production `TodayPage`/
    // `AppShell` keep them watched continuously. Matches
    // `learning_providers_test.dart`'s own `keepAlive()` convention.
    return container
      ..listen(authUserProvider, (_, _) {})
      ..listen(micControllerProvider, (_, _) {});
  }

  test('availability is ALWAYS MicPrepare — the mic never records directly '
      'on HOY, with or without a session', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);

    expect(target.availability, isA<MicPrepare>());

    await fakes.sessions.saveSession(
      DailySession(localDate: fakes.today, minutes: 10, challengeId: 'c1'),
    );
    await container.read(todayOverviewProvider.future);

    expect(target.availability, isA<MicPrepare>());
  });

  test('prompt says "Empezar la sesión de hoy" with no session, '
      '"Continuar la sesión de hoy" once one exists', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);

    expect(target.prompt.actionLabel, 'Empezar la sesión de hoy');

    await fakes.sessions.saveSession(
      DailySession(localDate: fakes.today, minutes: 10, challengeId: 'c1'),
    );
    await container.read(todayOverviewProvider.future);

    expect(target.prompt.actionLabel, 'Continuar la sesión de hoy');
  });

  test('the target notifies on changes once the session/label changes '
      '(via todayOverviewProvider)', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);
    final events = <void>[];
    final subscription = target.changes.listen(events.add);
    addTearDown(subscription.cancel);

    await fakes.sessions.saveSession(
      DailySession(localDate: fakes.today, minutes: 10, challengeId: 'c1'),
    );
    await container.read(todayOverviewProvider.future);

    expect(events, isNotEmpty);
  });

  test('onActivate with no session yet: never starts the recorder, plans '
      'today at the currently-selected duration, and fires '
      'onSessionStarted exactly once', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);
    container
        .read(todaySelectedBudgetProvider.notifier)
        .select(TimeBudget.thirty);
    var starts = 0;
    target.onSessionStarted = () => starts++;

    final prepare = target.availability as MicPrepare;
    await prepare.onActivate();

    expect(recorder.startCalls, 0);
    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.minutes, TimeBudget.thirty.minutes);
    expect(starts, 1);
  });

  test('onActivate with a session already persisted: does not call '
      'PlanToday again (no duplicate daily_sessions write), still fires '
      'onSessionStarted', () async {
    final container = build();
    addTearDown(container.dispose);
    await fakes.sessions.saveSession(
      DailySession(localDate: fakes.today, minutes: 10, challengeId: 'c1'),
    );
    await container.read(todayOverviewProvider.future);
    final target = container.read(todayStartTargetProvider);
    var starts = 0;
    target.onSessionStarted = () => starts++;

    final prepare = target.availability as MicPrepare;
    await prepare.onActivate();

    expect(recorder.startCalls, 0);
    expect((await fakes.sessions.fetchSessions()).valueOrNull, hasLength(1));
    expect(starts, 1);
  });

  test('onActivate with a planning failure: emits MicNotice.planFailed, '
      'never fires onSessionStarted, nothing is recorded', () async {
    final container = build();
    addTearDown(container.dispose);
    // Settles `authUserProvider` first — `micControllerProvider` reads
    // `currentUserIdProvider` (derived from it) and returns null until it
    // has, regardless of the `.listen` above (which only registers, it
    // does not synchronously await the first emission).
    await container.read(authUserProvider.future);
    final target = container.read(todayStartTargetProvider);
    // Lets the target's own constructor-triggered `todayOverviewProvider`
    // build settle successfully BEFORE injecting the failure below —
    // otherwise the synchronous `.listen()` call in the constructor only
    // SCHEDULES that build, and the injected failure would be consumed by
    // that unrelated cold build instead of `PlanToday.run`'s own save
    // call, reported as an unhandled zone error (same class of gotcha as
    // `plan_today_test.dart`'s own note).
    await container.read(todayOverviewProvider.future);
    var starts = 0;
    target.onSessionStarted = () => starts++;
    final notices = <MicNotice>[];
    container.read(micControllerProvider)!.notices.listen(notices.add);
    fakes.sessions.nextFailure = const NetworkFailure();

    final prepare = target.availability as MicPrepare;
    await prepare.onActivate();
    // Flushes the notice stream's own microtask delivery — `emitNotice`
    // schedules delivery to `notices` listeners asynchronously, which is
    // not guaranteed to have run yet at the exact instant `onActivate`'s
    // own Future completes.
    await Future<void>.value();

    expect(notices, [MicNotice.planFailed]);
    expect(starts, 0);
    expect(recorder.startCalls, 0);
    expect((await fakes.sessions.fetchSessions()).valueOrNull, isEmpty);
  });

  test('deliver is never a real path but stays safe if ever called', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);

    final delivery = await target.deliver(
      RecordedAudio(
        bytes: Uint8List.fromList(const [1]),
        mimeType: 'audio/wav',
        duration: const Duration(seconds: 1),
        levelsDbfs: const [],
      ),
    );

    expect(delivery, isA<MicDeliveryFailed>());
  });
}
