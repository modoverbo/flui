import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/training/domain/audio_consent_repository.dart';

/// In-memory `profiles.audio_retention_consent`, one value per user.
final class FakeAudioConsentRepository
    with FakeRemote
    implements AudioConsentRepository {
  new({required this.currentUserId, this.latency = Duration.zero});

  final String? Function() currentUserId;

  @override
  final Duration latency;

  final _consentByUser = <String, bool?>{};

  @override
  Future<Result<bool?>> read() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    return Result.ok(_consentByUser[userId]);
  }

  @override
  Future<Result<void>> write({required bool granted}) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    _consentByUser[userId] = granted;
    return const Result.ok(null);
  }
}
