import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/time_budget.dart';
import 'package:flui/features/daily/presentation/controllers/today_start_target.dart';
import 'package:flui/features/daily/presentation/providers/today_overview.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_fakes.dart';
import '../../../../helpers/test_container.dart';

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28],
);

void main() {
  late LearningFakes fakes;

  setUp(() => fakes = LearningFakes(speakingGym: true));
  tearDown(() => fakes.dispose());

  ProviderContainer build() {
    final container = createTestContainer(
      overrides: [
        ...fakes.overrides,
        speechAnalysisRepositoryProvider.overrideWithValue(
          FakeSpeechAnalysisRepository(latency: Duration.zero),
        ),
        attemptAudioStoreProvider.overrideWithValue(
          FakeAttemptAudioStore(currentUserId: () => LearningFakes.userId),
        ),
        audioConsentRepositoryProvider.overrideWithValue(
          FakeAudioConsentRepository(currentUserId: () => LearningFakes.userId),
        ),
      ],
    );
    // `PlanToday.run` reads `authUserProvider.future` via `ref.read`, not
    // `ref.watch` — with nothing else watching it, the autoDispose stream
    // provider can be torn down mid-flight before it ever emits (matches
    // `learning_providers_test.dart`'s own `keepAlive()` convention for
    // the exact same class of provider). `todayOverviewProvider` is
    // deliberately NOT pre-warmed here: in production `TodayPage` keeps it
    // watched continuously, but pre-warming it in this isolated test would
    // consume a single-shot injected repository failure before the test
    // meant to exercise it gets a chance to (see the dedicated
    // `await container.read(todayOverviewProvider.future)` in the tests
    // that need it already settled).
    return container..listen(authUserProvider, (_, _) {});
  }

  test('before a session exists, availability is MicReady — one gesture '
      'both plans and records, never a second-activation prompt', () {
    final container = build();
    addTearDown(container.dispose);

    final target = container.read(todayStartTargetProvider);

    expect(target.availability, isA<MicReady>());
  });

  test('deliver with no session yet plans today at the currently-selected '
      'duration, then submits the audio into the new loop', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);

    final delivery = await target.deliver(_audio());

    expect(delivery, isA<MicAccepted>());
    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.minutes, TimeBudget.ten.minutes);
    expect(fakes.speakingAttempts.attemptsForCurrentUser, hasLength(1));
  });

  test('a duration chip selected before the gesture plans at that duration, '
      'not the default preselected one', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);
    container
        .read(todaySelectedBudgetProvider.notifier)
        .select(TimeBudget.thirty);

    await target.deliver(_audio());

    final saved = (await fakes.sessions.fetchSessions()).valueOrNull!.single;
    expect(saved.minutes, TimeBudget.thirty.minutes);
  });

  test("once a session exists, availability/prompt delegate to that day's "
      'LoopMicTarget', () async {
    final container = build();
    addTearDown(container.dispose);
    await fakes.sessions.saveSession(
      DailySession(localDate: fakes.today, minutes: 10, challengeId: 'c1'),
    );
    // Settles the same chain `TodayPage` keeps continuously watched in
    // production, so the just-saved session is visible before this
    // target's own `_loopTarget` getter reads it back.
    await container.read(todayOverviewProvider.future);
    final target = container.read(todayStartTargetProvider);

    expect(target.availability, isA<MicReady>());
    expect(target.prompt.actionLabel, isNot('Grabar tu respuesta de hoy'));
  });

  test(
    'deliver once a session exists forwards straight to the loop, no '
    'second PlanToday.run call (no duplicate daily_sessions write)',
    () async {
      final container = build();
      addTearDown(container.dispose);
      await fakes.sessions.saveSession(
        DailySession(localDate: fakes.today, minutes: 10),
      );
      await container.read(todayOverviewProvider.future);
      final target = container.read(todayStartTargetProvider);

      await target.deliver(_audio());

      expect((await fakes.sessions.fetchSessions()).valueOrNull, hasLength(1));
      expect(fakes.speakingAttempts.attemptsForCurrentUser, hasLength(1));
    },
  );

  test('onSessionStarted fires exactly once, only on the FIRST successful '
      'deliver that creates the session', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);
    var calls = 0;
    target.onSessionStarted = () => calls++;

    await target.deliver(_audio());
    await target.deliver(_audio());

    expect(calls, 1);
  });

  test('a PlanToday failure surfaces MicDeliveryFailed, never calls the '
      'loop (no paid analysis, no attempt persisted)', () async {
    final container = build();
    addTearDown(container.dispose);
    final target = container.read(todayStartTargetProvider);
    // Settles the "no session yet" read successfully first, so the
    // failure injected below is the one `PlanToday.run`'s own SAVE call
    // hits (a plain `Result.err`, handled by its own try/catch), never an
    // unrelated cold build failure of the same provider chain `deliver`'s
    // own `_loopTarget` pre-check also happens to read.
    await container.read(todayOverviewProvider.future);
    fakes.sessions.nextFailure = const NetworkFailure();

    final delivery = await target.deliver(_audio());

    expect(delivery, isA<MicDeliveryFailed>());
    expect(fakes.speakingAttempts.attemptsForCurrentUser, isEmpty);
  });
}
