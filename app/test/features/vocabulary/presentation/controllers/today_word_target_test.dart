import 'dart:typed_data';

import 'package:flui/core/audio/recorded_audio.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/mic/mic_target.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/presentation/providers/daily_providers.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flui/features/profile/data/fake_streak_repair_repository.dart';
import 'package:flui/features/profile/presentation/providers/profile_providers.dart';
import 'package:flui/features/speaking/data/fake_speech_analysis_repository.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flui/features/vocabulary/data/fake_content_repository.dart';
import 'package:flui/features/vocabulary/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/vocabulary/data/fake_word_progress_repository.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flui/features/vocabulary/presentation/controllers/today_word_target.dart';
import 'package:flui/features/vocabulary/presentation/providers/exercise_providers.dart';
import 'package:flui/features/vocabulary/presentation/providers/today_words.dart';
import 'package:flui/features/vocabulary/presentation/providers/vocabulary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/learning_builders.dart';

const AppUser _ana = AppUser(id: 'u1', email: 'ana@correo.com');

// "organizar"/"elocuente": `FakeSpeechAnalysisRepository`'s fixed
// first-attempt transcript contains "organizar" but never "elocuente".
final Word _due = buildWord(id: 'w-organizar', lemma: 'organizar');
final Word _laterDue = buildWord(id: 'w-elocuente', lemma: 'elocuente');

RecordedAudio _audio() => RecordedAudio(
  bytes: Uint8List.fromList(List<int>.filled(10, 1)),
  mimeType: 'audio/wav',
  duration: const Duration(seconds: 12),
  levelsDbfs: const [-30, -28],
);

void main() {
  late ProviderContainer container;
  late FakeWordProgressRepository wordProgress;

  setUp(() async {
    wordProgress = FakeWordProgressRepository(currentUserId: () => _ana.id);
    final consent = FakeAudioConsentRepository(currentUserId: () => _ana.id);
    await consent.write(granted: true);
    // Keeps `authUserProvider`/`todayWordsProvider` alive across the async
    // gaps below — `TodayWordTarget`'s own constructor listens to
    // `todayWordsProvider`, but nothing else retains that chain in a plain
    // `ProviderContainer` test (matches `today_start_target_test.dart`'s
    // own established convention).
    container =
        ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(
                FakeAuthRepository(initialUser: _ana),
              ),
              speechAnalysisRepositoryProvider.overrideWithValue(
                FakeSpeechAnalysisRepository(latency: Duration.zero),
              ),
              speakingAttemptRepositoryProvider.overrideWithValue(
                FakeSpeakingAttemptRepository(currentUserId: () => _ana.id),
              ),
              attemptAudioStoreProvider.overrideWithValue(
                FakeAttemptAudioStore(currentUserId: () => _ana.id),
              ),
              audioConsentRepositoryProvider.overrideWithValue(consent),
              challengeRepositoryProvider.overrideWithValue(
                FakeChallengeRepository(),
              ),
              contentRepositoryProvider.overrideWithValue(
                FakeContentRepository(words: [_due, _laterDue]),
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
              clockProvider.overrideWithValue(
                FixedClock(DateTime(2026, 9, 13, 10)),
              ),
            ],
          )
          ..listen(authUserProvider, (_, _) {})
          ..listen(todayWordTargetProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  TodayWordTarget target() => container.read(todayWordTargetProvider);

  Future<void> settle() async {
    await container.read(authUserProvider.future);
    await container.read(todayWordsProvider.future);
  }

  test(
    'no due words -> MicPassThrough, the registry falls to the fallback',
    () async {
      await settle();

      expect(target().availability, isA<MicPassThrough>());
    },
  );

  test('a due word resolves ready, labeled "Úsala en voz alta"', () async {
    await wordProgress.saveProgress(
      buildProgress(wordId: _due.id, nextDueOn: day(13)),
    );
    await settle();

    expect(target().prompt.actionLabel, 'Úsala en voz alta');
    expect(target().availability, isA<MicReady>());
  });

  test('delivering the top due word saves it and calls onWordSpeakStarted with '
      "that word's id", () async {
    await wordProgress.saveProgress(
      buildProgress(wordId: _due.id, nextDueOn: day(13)),
    );
    await settle();
    final startedFor = <String>[];
    target().onWordSpeakStarted = startedFor.add;

    final delivery = await target().deliver(_audio());

    expect(delivery, isA<MicAccepted>());
    expect(startedFor, [_due.id]);
  });

  test(
    'when the due word changes, changes fires and the new prompt follows it',
    () async {
      await wordProgress.saveProgress(
        buildProgress(wordId: _due.id, nextDueOn: day(20)),
      );
      await settle();
      var fired = 0;
      final subscription = target().changes.listen((_) => fired++);

      await container
          .read(learningDataControllerProvider(_ana.id).notifier)
          .saveProgress(buildProgress(wordId: _laterDue.id, nextDueOn: day(1)));
      await container.read(todayWordsProvider.future);
      await pumpEventQueue();

      expect(fired, greaterThan(0));
      expect(target().prompt.actionLabel, 'Úsala en voz alta');
      await subscription.cancel();
    },
  );
}
