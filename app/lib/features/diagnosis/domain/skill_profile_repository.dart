import 'package:flui/core/error/result.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:meta/meta.dart';

/// Whether a persisted [SkillProfileRecord] closed a first-ever diagnosis or
/// a later retake (design D8, part-3 §5: server-trigger-owned, never
/// client-set).
enum SkillProfileKind { baseline, retake }

/// A persisted `skill_profiles` row: the profiling result plus its
/// database-owned identity. [id] is the diagnosis session id that closed
/// (design D38); [kind] and [diagnosedAt] are set by the
/// `skill_profiles_before_insert` trigger, never by the client.
@immutable
final class SkillProfileRecord {
  const new({
    required this.id,
    required this.kind,
    required this.diagnosedAt,
    required this.profile,
  });

  final String id;
  final SkillProfileKind kind;
  final DateTime diagnosedAt;
  final SkillProfile profile;

  @override
  bool operator ==(Object other) =>
      other is SkillProfileRecord &&
      other.id == id &&
      other.kind == kind &&
      other.diagnosedAt == diagnosedAt &&
      other.profile == profile;

  @override
  int get hashCode => Object.hash(id, kind, diagnosedAt, profile);

  @override
  String toString() => 'SkillProfileRecord($id, $kind, $diagnosedAt)';
}

/// The signed-in user's `skill_profiles` (one row per closed diagnosis
/// session, design part-3 §5).
abstract interface class SkillProfileRepository {
  /// The most recently diagnosed profile, or `null` if none exists yet.
  Future<Result<SkillProfileRecord?>> latest();

  /// Every diagnosed profile, most recent first.
  Future<Result<List<SkillProfileRecord>>> history();

  /// Persists [profile] as the profile closing diagnosis session
  /// [sessionId].
  ///
  /// `kind` and `diagnosedAt` are assigned server-side. A retake attempted
  /// less than 30 days after the previous one is rejected with a
  /// `SkillProfileFailure(SkillProfileErrorCode.retakeTooSoon)` — the caller
  /// derives the available date itself (e.g. via `RetakePolicy`) from the
  /// last known profile.
  Future<Result<SkillProfileRecord>> save({
    required String sessionId,
    required SkillProfile profile,
  });
}
