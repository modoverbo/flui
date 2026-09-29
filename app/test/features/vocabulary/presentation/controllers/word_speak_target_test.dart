import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/profile/data/fake_streak_repair_repository.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_loop.dart';
import 'package:flui/features/training/presentation/controllers/training_loop_controller.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/controllers/word_speak_target.dart';
import 'package:flui/features/vocabulary/presentation/providers/exercise_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_builders.dart';

const AppUser _ana = AppUser(id: 'u1', email: 'ana@correo.com');

// "organizar" is chosen because `FakeSpeechAnalysisRepository`'s fixed
// first-attempt transcript ("...decisión importante... organizar mejor mi
// mañana para trabajar con más claridad.") actually contains it.
final Word _word = buildWord(id: 'w-organizar', lemma: 'organizar');

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28],
);

void main() {
  late ProviderContainer container;
  late FakeSpeechAnalysisRepository speech;
  late FakeSpeakingAttemptRepository attempts;
  late FakeWordProgressRepository wordProgress;

  setUp(() async {
    speech = FakeSpeechAnalysisRepository(latency: Duration.zero);
    attempts = FakeSpeakingAttemptRepository(currentUserId: () => _ana.id);
    wordProgress = FakeWordProgressRepository(currentUserId: () => _ana.id);
    final consent = FakeAudioConsentRepository(currentUserId: () => _ana.id);
    await consent.write(granted: true);
    await wordProgress.saveProgress(
      buildProgress(wordId: _word.id, nextDueOn: day(28)),
    );

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initialUser: _ana),
        ),
        speechAnalysisRepositoryProvider.overrideWithValue(speech),
        speakingAttemptRepositoryProvider.overrideWithValue(attempts),
        attemptAudioStoreProvider.overrideWithValue(
          FakeAttemptAudioStore(currentUserId: () => _ana.id),
        ),
        audioConsentRepositoryProvider.overrideWithValue(consent),
        challengeRepositoryProvider.overrideWithValue(
          FakeChallengeRepository(),
        ),
        contentRepositoryProvider.overrideWithValue(
          FakeContentRepository(words: [_word]),
        ),
        wordProgressRepositoryProvider.overrideWithValue(wordProgress),
        dailySessionRepositoryProvider.overrideWithValue(
          FakeDailySessionRepository(currentUserId: () => _ana.id),
        ),
        exerciseAttemptRepositoryProvider.overrideWithValue(
          FakeExerciseAttemptRepository(currentUserId: () => _ana.id),
        ),
        streakRepairRepositoryProvider.overrideWithValue(
          FakeStreakRepairRepository(currentUserId: () => _ana.id),
        ),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 28))),
      ],
    );
    addTearDown(container.dispose);
    // Keeps `authUserProvider` alive across the async gap inside
    // `TrainingLoopController._recordSpokenUse` (`ref.readFuture`) —
    // matches `today_start_target_test.dart`'s own established workaround.
    container.listen(authUserProvider, (_, _) {});
  });

  // Keeps whichever `wordSpeakTargetProvider(wordId)` entry is currently
  // live pinned across an `await` gap — a bare `.read()` survives only
  // within the SAME synchronous frame; tests that `await` after reading
  // (or explicitly `container.invalidate(...)` + re-read, simulating a
  // fresh mount) need this or the autoDispose entry can be torn down
  // mid-test, taking its own `Ref` down with it.
  WordSpeakTarget target() {
    container.listen(wordSpeakTargetProvider(_word.id), (_, _) {});
    return container.read(wordSpeakTargetProvider(_word.id));
  }

  test(
    'the unstarted first attempt is labeled "Úsala en voz alta" and ready',
    () {
      final t = target();

      expect(t.prompt.actionLabel, 'Úsala en voz alta');
      expect(t.availability, isA<MicReady>());
    },
  );

  test('delivering the first attempt saves it (context=word), records mastery, '
      'and calls onDelivered exactly once', () async {
    final t = target();
    var delivered = 0;
    t.onDelivered = () => delivered++;

    final delivery = await t.deliver(_audio());

    expect(delivery, isA<MicAccepted>());
    expect(delivered, 1);
    final saved = attempts.attemptsForCurrentUser.single;
    expect(saved.context, TrainingContext.word);
    expect(saved.targetWordIds, [_word.id]);
    expect(saved.wordsUsed, [_word.id]);
    final progress = (await wordProgress.fetchProgress()).valueOrNull!;
    final after = progress.single;
    expect(after.ladderStep, 1);
    expect(after.productionDone, isTrue);
  });

  test(
    'a blocked delivery (access required) never calls onDelivered',
    () async {
      speech.nextFailure = const SpeechAnalysisFailure(
        SpeechAnalysisErrorCode.accessRequired,
      );
      final t = target();
      var delivered = 0;
      t.onDelivered = () => delivered++;

      final delivery = await t.deliver(_audio());

      expect(delivery, isA<MicAccessRequired>());
      expect(delivered, 0);
      expect(attempts.attemptsForCurrentUser, isEmpty);
    },
  );

  test(
    'after the first attempt is delivered, the prompt hands off to the '
    "shared loop's own wording (repeat step), not the static label",
    () async {
      final t = target();

      await t.deliver(_audio());

      expect(t.prompt.actionLabel, isNot('Úsala en voz alta'));
      expect(t.prompt.actionLabel, 'Grabar tu repetición');
    },
  );

  test('maxDuration delegates to the shared loop target (60s ceiling)', () {
    expect(target().maxDuration, const Duration(seconds: 60));
  });

  test('changes fires whenever the wrapped loop state changes', () async {
    var fired = 0;
    final t = target();
    final subscription = t.changes.listen((_) => fired++);

    await t.deliver(_audio());
    await pumpEventQueue();

    expect(fired, greaterThan(0));
    await subscription.cancel();
  });

  group('finished loop resets on the NEXT construction (orchestrator review '
      'finding: keepAlive session id + keepAlive controller leaked a '
      'finished loop forever)', () {
    // A real "leave `/words/:id`, come back" cycle disposes the OLD
    // `WordSpeakTarget` (its `MicTargetScope` registration unmounts,
    // `wordSpeakTargetProvider`'s last listener drops, autoDispose tears
    // it down — `dispose()` closes its wrapped `LoopMicTarget`'s own
    // subscriptions) BEFORE the new mount ever reads a fresh instance.
    // `.close()` on the subscription below is what reproduces that exact
    // release; skipping it would leave the OLD `LoopMicTarget` subscribed
    // to the finished `TrainingLoopController` at the same time the reset
    // tries to invalidate it — an artifact of a bare `ProviderContainer`
    // test, not a real production path.
    ProviderSubscription<WordSpeakTarget> mount() =>
        container.listen(wordSpeakTargetProvider(_word.id), (_, _) {});

    test('a loop finished (comparison — wordUse has no summary phase) mints a '
        'new session id, so the word is offered again instead of staying '
        "stuck offering the previous loop's own finished state", () async {
      final firstMount = mount();
      final first = firstMount.read();
      await first.deliver(_audio()); // -> feedback
      await first.deliver(_audio()); // -> comparison (finished)
      final finishedRequest = first.request;
      expect(
        container
            .read(trainingLoopControllerProvider(finishedRequest))
            .loop
            .phase,
        LoopPhase.comparison,
      );

      firstMount.close();
      await Future<void>.delayed(Duration.zero);
      container.invalidate(wordSpeakTargetProvider(_word.id));
      final second = mount().read();

      // A brand new session/loop, never stuck at the finished one, and
      // never falling through to a lab-fallback/quick-practice
      // passthrough either.
      expect(second.request.sessionId, isNot(finishedRequest.sessionId));
      expect(second.prompt.actionLabel, 'Úsala en voz alta');
      expect(second.availability, isA<MicReady>());
      // `resetIfFinished` deliberately does NOT invalidate the OLD
      // `TrainingLoopController` family entry — see its own doc comment
      // in `word_speak_target.dart`: doing so was verified (in complete
      // isolation AND in a real app run) to crash the app later via a
      // scheduled Riverpod refresh (`LateInitializationError` on a
      // `late final` field, from calling `build()` twice on the SAME
      // cached notifier object once it has zero listeners — a
      // pre-existing property of any `keepAlive` class-based Notifier,
      // not something this fix could safely patch). The OLD entry is
      // simply abandoned — proven safe because it still `exists()`
      // (nothing crashed reaching this point) while `second` operates
      // on a genuinely different, independent session id.
      expect(
        container.exists(trainingLoopControllerProvider(finishedRequest)),
        isTrue,
      );
    });

    test(
      'a loop still mid-flow (feedback, not yet comparison) is NOT reset — '
      'resuming exactly where it left off, matching the resume pattern used '
      'elsewhere (design says nothing to the contrary for word context)',
      () async {
        final firstMount = mount();
        final first = firstMount.read();
        await first.deliver(_audio()); // -> feedback, not finished yet
        final midFlowRequest = first.request;

        firstMount.close();
        container.invalidate(wordSpeakTargetProvider(_word.id));
        final second = mount().read();

        expect(second.request.sessionId, midFlowRequest.sessionId);
        expect(second.prompt.actionLabel, 'Grabar tu repetición');
      },
    );

    test('mastery does not over-count: completing the loop again after a '
        'reset, on the SAME day, never advances the ladder a second time '
        "(SpokenWordUse.review's own isDueOn(today) guard)", () async {
      final firstMount = mount();
      final first = firstMount.read();
      await first.deliver(_audio()); // -> feedback, ladderStep 1
      await first.deliver(_audio()); // -> comparison, still ladderStep 1
      final afterFirstLoop =
          (await wordProgress.fetchProgress()).valueOrNull!.single;
      expect(afterFirstLoop.ladderStep, 1);

      firstMount.close();
      container.invalidate(wordSpeakTargetProvider(_word.id));
      final second = mount().read();
      await second.deliver(_audio()); // fresh first attempt, same day

      final afterSecondLoop =
          (await wordProgress.fetchProgress()).valueOrNull!.single;
      expect(afterSecondLoop.ladderStep, 1);
    });
  });
}
