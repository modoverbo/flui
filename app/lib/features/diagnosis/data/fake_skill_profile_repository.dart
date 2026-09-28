import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/domain/skill_profile.dart';

/// In-memory `skill_profiles`, mirroring the server trigger's
/// kind/30-day-retake enforcement (design part-3 §5).
final class FakeSkillProfileRepository
    with FakeRemote
    implements SkillProfileRepository {
  new({
    required this.currentUserId,
    this.latency = Duration.zero,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String? Function() currentUserId;
  final DateTime Function() _now;

  @override
  final Duration latency;

  static const _retakeCooldown = Duration(days: 30);

  final _recordsByUser = <String, List<SkillProfileRecord>>{};

  /// Seeds an already-diagnosed profile for the signed-in user, bypassing
  /// `save()`'s async retake-cooldown check — matches
  /// `FakeSubscriptionRepository.grantAccess`'s synchronous-seed shape, for
  /// tests that need diagnosis already completed rather than exercising it.
  void seedProfile(SkillProfileRecord record) {
    final userId = currentUserId();
    if (userId == null) return;
    _recordsByUser.putIfAbsent(userId, () => []).add(record);
  }

  @override
  Future<Result<SkillProfileRecord?>> latest() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    final records = _recordsByUser[userId];
    return Result.ok(records == null || records.isEmpty ? null : records.last);
  }

  @override
  Future<Result<List<SkillProfileRecord>>> history() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    return Result.ok(
      [...?_recordsByUser[userId]].reversed.toList(growable: false),
    );
  }

  @override
  Future<Result<SkillProfileRecord>> save({
    required String sessionId,
    required SkillProfile profile,
  }) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);

    final existing = _recordsByUser[userId] ?? const <SkillProfileRecord>[];
    final last = existing.isEmpty ? null : existing.last;
    if (last != null && _now().difference(last.diagnosedAt) < _retakeCooldown) {
      return const Result.err(
        SkillProfileFailure(SkillProfileErrorCode.retakeTooSoon),
      );
    }

    final record = SkillProfileRecord(
      id: sessionId,
      kind: last == null ? SkillProfileKind.baseline : SkillProfileKind.retake,
      diagnosedAt: _now(),
      profile: profile,
    );
    _recordsByUser.putIfAbsent(userId, () => []).add(record);
    return Result.ok(record);
  }
}
