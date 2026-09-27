import 'package:flui/core/error/result.dart';

/// The signed-in user's `profiles.audio_retention_consent` (design part-3
/// §5): `null` means the question has never been asked.
abstract interface class AudioConsentRepository {
  /// The current consent value.
  Future<Result<bool?>> read();

  /// Sets consent to [granted]. The server stamps
  /// `audio_consent_updated_at` whenever the value actually changes.
  Future<Result<void>> write({required bool granted});
}
