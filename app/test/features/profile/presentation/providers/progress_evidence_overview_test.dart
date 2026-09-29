import 'dart:typed_data';

import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/diagnosis/presentation/providers/diagnosis_providers.dart';
import 'package:flui/features/profile/domain/before_now_audio.dart';
import 'package:flui/features/profile/domain/progress_evidence.dart';
import 'package:flui/features/profile/presentation/providers/progress_evidence_overview.dart';
import 'package:flui/features/training/data/fake_attempt_audio_store.dart';
import 'package:flui/features/training/data/fake_audio_consent_repository.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flui/features/training/presentation/providers/training_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _metrics = VoiceMetrics(longPauses: 0, usefulPauses: 0, fillerCount: 0);
const _userId = 'u1';

SpeakingAttempt _attempt({
  required String id,
  required String sessionId,
  TrainingContext context = TrainingContext.diagnosis,
  AudioRetention audio = const AudioRetention.none(),
  LocalDate? milestoneWeek,
  List<Observation> observations = const [],
  LocalDate? localDate,
}) => SpeakingAttempt(
  id: id,
  sessionId: sessionId,
  context: context,
  kind: AttemptKind.first,
  localDate: localDate ?? LocalDate(2026, 9, 20),
  transcript: 'Hola, esto es una prueba.',
  duration: const Duration(seconds: 20),
  metrics: _metrics,
  audio: audio,
  observations: observations,
  milestoneWeek: milestoneWeek,
);

const _opportunity = Observation(
  code: BehaviorCode.mainPointLate,
  source: ObservationSource.ai,
);
const _strength = Observation(
  code: BehaviorCode.clearMainPoint,
  source: ObservationSource.ai,
);

SkillProfile _profile() => const SkillProfile(
  topArea: SkillArea.thinking,
  secondArea: SkillArea.language,
  strengths: [BehaviorCode.preciseWord],
  evidence: [],
);

void main() {
  late FakeSpeakingAttemptRepository attempts;
  late FakeSkillProfileRepository profiles;
  late FakeAttemptAudioStore audioStore;
  late FakeAudioConsentRepository consent;
  late ProviderContainer container;

  setUp(() {
    attempts = FakeSpeakingAttemptRepository(currentUserId: () => _userId);
    profiles = FakeSkillProfileRepository(currentUserId: () => _userId);
    audioStore = FakeAttemptAudioStore(currentUserId: () => _userId);
    consent = FakeAudioConsentRepository(currentUserId: () => _userId);
    container = ProviderContainer(
      overrides: [
        speakingAttemptRepositoryProvider.overrideWithValue(attempts),
        skillProfileRepositoryProvider.overrideWithValue(profiles),
        attemptAudioStoreProvider.overrideWithValue(audioStore),
        audioConsentRepositoryProvider.overrideWithValue(consent),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 9, 20))),
      ],
    );
    addTearDown(container.dispose);
  });

  group('progressEvidenceOverviewProvider', () {
    test('is empty with no diagnosed profile yet', () async {
      final overview = await container.read(
        progressEvidenceOverviewProvider.future,
      );

      expect(overview.evidence.beforeNow, isA<BeforeNowInsufficientEvidence>());
      expect(overview.audio, const BeforeNowAudioUnavailable());
    });

    test('with no retake: baseline is the diagnosis session, now is the '
        'last-14-days window (decision #429 indicative comparison)', () async {
      profiles.seedProfile(
        SkillProfileRecord(
          id: 'baseline',
          kind: SkillProfileKind.baseline,
          diagnosedAt: DateTime(2026, 8, 2),
          profile: _profile(),
        ),
      );
      await attempts.insert(
        _attempt(
          id: 'b1',
          sessionId: 'baseline',
          observations: const [_opportunity, _strength],
        ),
      );
      // Outside the 14-day window (before 2026-09-06): must never count.
      await attempts.insert(
        _attempt(
          id: 'old',
          sessionId: 'daily-old',
          context: TrainingContext.daily,
          localDate: LocalDate(2026, 8, 20),
          observations: const [_opportunity, _strength],
        ),
      );
      // Inside the window.
      await attempts.insert(
        _attempt(
          id: 'recent',
          sessionId: 'daily-recent',
          context: TrainingContext.daily,
          localDate: LocalDate(2026, 9, 10),
          observations: const [_strength, _strength],
        ),
      );

      final overview = await container.read(
        progressEvidenceOverviewProvider.future,
      );

      final beforeNow = overview.evidence.beforeNow;
      expect(beforeNow, isA<BeforeNowComparison>());
      expect(
        (beforeNow as BeforeNowComparison).label,
        BeforeNowLabel.indicative,
      );
    });

    test('with a completed retake: baseline is the ORIGINAL diagnosis '
        'session (not the retake), now is the retake (formal comparison, '
        'decision #429)', () async {
      profiles
        ..seedProfile(
          SkillProfileRecord(
            id: 'baseline',
            kind: SkillProfileKind.baseline,
            diagnosedAt: DateTime(2026, 6, 2),
            profile: _profile(),
          ),
        )
        ..seedProfile(
          SkillProfileRecord(
            id: 'retake',
            kind: SkillProfileKind.retake,
            diagnosedAt: DateTime(2026, 8, 2),
            profile: _profile(),
          ),
        );
      await attempts.insert(
        _attempt(
          id: 'baseline-1',
          sessionId: 'baseline',
          observations: const [_opportunity],
        ),
      );
      await attempts.insert(
        _attempt(
          id: 'retake-1',
          sessionId: 'retake',
          observations: const [_strength, _strength],
        ),
      );

      final overview = await container.read(
        progressEvidenceOverviewProvider.future,
      );

      final beforeNow = overview.evidence.beforeNow;
      expect(beforeNow, isA<BeforeNowComparison>());
      expect((beforeNow as BeforeNowComparison).label, BeforeNowLabel.formal);
      // Thinking trend must be driven by baseline-1's opportunity (needsWork
      // would require a NOW opportunity; here the baseline session's own
      // rows, not the retake's, must feed the "before" side).
    });

    test('pairs the baseline audio with the latest stored milestone', () async {
      profiles.seedProfile(
        SkillProfileRecord(
          id: 'baseline',
          kind: SkillProfileKind.baseline,
          diagnosedAt: DateTime(2026, 8, 2),
          profile: _profile(),
        ),
      );
      await attempts.insert(
        _attempt(
          id: 'b1',
          sessionId: 'baseline',
          audio: const AudioRetention.stored(
            path: '$_userId/b1.wav',
            mime: 'audio/wav',
          ),
        ),
      );
      await attempts.insert(
        _attempt(
          id: 'm1',
          sessionId: 'daily',
          context: TrainingContext.daily,
          audio: const AudioRetention.stored(
            path: '$_userId/m1.wav',
            mime: 'audio/wav',
          ),
          milestoneWeek: LocalDate(2026, 9, 14),
        ),
      );

      final overview = await container.read(
        progressEvidenceOverviewProvider.future,
      );

      expect(
        overview.audio,
        const BeforeNowAudioAvailable(
          beforeAttemptId: 'b1',
          beforePath: '$_userId/b1.wav',
          beforeMime: 'audio/wav',
          nowAttemptId: 'm1',
          nowPath: '$_userId/m1.wav',
          nowMime: 'audio/wav',
        ),
      );
    });
  });

  group('AudioConsentController', () {
    test('writes consent and refreshes audioConsentProvider', () async {
      expect(await container.read(audioConsentProvider.future), isNull);

      final result = await container
          .read(audioConsentControllerProvider.notifier)
          .setConsent(granted: true);

      expect(result.isOk, isTrue);
      expect(await container.read(audioConsentProvider.future), isTrue);
    });
  });

  group('AudioDeletionController', () {
    test("deleteOne removes a stored attempt's audio and refreshes the "
        'overview', () async {
      profiles.seedProfile(
        SkillProfileRecord(
          id: 'baseline',
          kind: SkillProfileKind.baseline,
          diagnosedAt: DateTime(2026, 8, 2),
          profile: _profile(),
        ),
      );
      await attempts.insert(
        _attempt(
          id: 'b1',
          sessionId: 'baseline',
          audio: const AudioRetention.stored(
            path: '$_userId/b1.wav',
            mime: 'audio/wav',
          ),
        ),
      );
      await audioStore.upload(
        attemptId: 'b1',
        bytes: Uint8List.fromList([1]),
        mimeType: 'audio/wav',
      );

      final result = await container
          .read(audioDeletionControllerProvider.notifier)
          .deleteOne('b1');

      expect(result.isOk, isTrue);
      expect(audioStore.statusOf('b1'), const AudioRetention.deleted());
    });

    test('deleteOne on an attempt with no stored audio is graceful, no '
        'error', () async {
      final result = await container
          .read(audioDeletionControllerProvider.notifier)
          .deleteOne('never-uploaded');

      expect(result.isOk, isTrue);
    });

    test(
      'deleteAll removes every stored attempt for the current user only',
      () async {
        final other = FakeSpeakingAttemptRepository(currentUserId: () => 'u2');
        final otherContainer = ProviderContainer(
          overrides: [
            speakingAttemptRepositoryProvider.overrideWithValue(other),
          ],
        );
        addTearDown(otherContainer.dispose);

        await attempts.insert(
          _attempt(
            id: 'a1',
            sessionId: 's1',
            audio: const AudioRetention.stored(
              path: '$_userId/a1.wav',
              mime: 'audio/wav',
            ),
          ),
        );
        await attempts.insert(
          _attempt(
            id: 'a2',
            sessionId: 's1',
            audio: const AudioRetention.stored(
              path: '$_userId/a2.wav',
              mime: 'audio/wav',
            ),
          ),
        );
        await audioStore.upload(
          attemptId: 'a1',
          bytes: Uint8List.fromList([1]),
          mimeType: 'audio/wav',
        );
        await audioStore.upload(
          attemptId: 'a2',
          bytes: Uint8List.fromList([1]),
          mimeType: 'audio/wav',
        );

        final result = await container
            .read(audioDeletionControllerProvider.notifier)
            .deleteAll();

        expect(result.isOk, isTrue);
        expect(audioStore.statusOf('a1'), const AudioRetention.deleted());
        expect(audioStore.statusOf('a2'), const AudioRetention.deleted());
      },
    );

    test('deleteAll with nothing stored is a graceful no-op', () async {
      final result = await container
          .read(audioDeletionControllerProvider.notifier)
          .deleteAll();

      expect(result.isOk, isTrue);
    });

    test('deleteOne surfaces a genuine failure (not the nothing-to-delete '
        'shape) honestly', () async {
      profiles.seedProfile(
        SkillProfileRecord(
          id: 'baseline',
          kind: SkillProfileKind.baseline,
          diagnosedAt: DateTime(2026, 8, 2),
          profile: _profile(),
        ),
      );
      await attempts.insert(
        _attempt(
          id: 'b1',
          sessionId: 'baseline',
          audio: const AudioRetention.stored(
            path: '$_userId/b1.wav',
            mime: 'audio/wav',
          ),
        ),
      );
      await audioStore.upload(
        attemptId: 'b1',
        bytes: Uint8List.fromList([1]),
        mimeType: 'audio/wav',
      );
      audioStore.nextFailure = const NetworkFailure();

      final result = await container
          .read(audioDeletionControllerProvider.notifier)
          .deleteOne('b1');

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
