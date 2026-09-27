import 'package:flui/features/training/domain/attempt_audio_store.dart';
import 'package:flui/features/training/domain/audio_consent_repository.dart';
import 'package:flui/features/training/domain/challenge_repository.dart';
import 'package:flui/features/training/domain/speaking_attempt_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests, matching
/// `features/speaking/presentation/providers/speaking_providers.dart`'s
/// established shape for a plain repository port.
final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => throw UnimplementedError(
    'challengeRepositoryProvider must be overridden.',
  ),
);

final speakingAttemptRepositoryProvider = Provider<SpeakingAttemptRepository>(
  (ref) => throw UnimplementedError(
    'speakingAttemptRepositoryProvider must be overridden.',
  ),
);

final attemptAudioStoreProvider = Provider<AttemptAudioStore>(
  (ref) =>
      throw UnimplementedError('attemptAudioStoreProvider must be overridden.'),
);

final audioConsentRepositoryProvider = Provider<AudioConsentRepository>(
  (ref) => throw UnimplementedError(
    'audioConsentRepositoryProvider must be overridden.',
  ),
);
