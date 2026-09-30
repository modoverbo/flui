import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_profile_dto.freezed.dart';
part 'skill_profile_dto.g.dart';

/// A `public.skill_profiles` row (design part-3 §5).
///
/// `kind` and `diagnosedAt` are omitted when building an insert body — the
/// `skill_profiles_before_insert` trigger owns both — and always present on
/// a row read back from the database.
///
/// `topBehavior`/`secondBehavior` are honestly nullable and `strengths` may
/// be empty: `DiagnosisProfiler` leaves a behavior null whenever its area
/// had zero opportunities across all 3 attempts, and strengths come only
/// from areas other than top/second, so an all-opportunity diagnosis
/// legitimately has none. Never fabricated to satisfy a shape.
@freezed
abstract class SkillProfileDto with _$SkillProfileDto {
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory({
    required String id,
    required String topArea,
    required String secondArea,
    required List<Object?> strengths,
    required List<Object?> evidence,
    // `includeIfNull: true` overrides the class default above so a null
    // behavior is written as an explicit JSON `null`, never omitted — the
    // key must always be present for `SkillProfileDto.fromJson` to round
    // trip it, and omitting it would silently keep whatever the server
    // defaults to instead of persisting the honest gap.
    @JsonKey(includeIfNull: true) String? topBehavior,
    @JsonKey(includeIfNull: true) String? secondBehavior,
    String? kind,
    String? diagnosedAt,
  }) = _SkillProfileDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$SkillProfileDtoFromJson(json);

  /// The insert body for a newly closed diagnosis session [id].
  factory forInsert({required String id, required SkillProfile profile}) =>
      SkillProfileDto(
        id: id,
        topArea: profile.topArea.name,
        secondArea: profile.secondArea.name,
        // Never force-unwrapped: a real diagnosis can legitimately leave
        // either one null (see the class doc above).
        topBehavior: profile.topBehavior?.wireCode,
        secondBehavior: profile.secondBehavior?.wireCode,
        strengths: [for (final code in profile.strengths) code.wireCode],
        evidence: [
          for (final e in profile.evidence)
            {'attempt_id': e.attemptId, 'code': e.code.wireCode},
        ],
      );

  const new _();

  static const columns =
      'id, kind, top_area, second_area, top_behavior, second_behavior, '
      'strengths, evidence, diagnosed_at';

  SkillProfileRecord toDomain() {
    final topBehavior = this.topBehavior;
    final secondBehavior = this.secondBehavior;
    return SkillProfileRecord(
      id: id,
      kind: kind == 'retake'
          ? SkillProfileKind.retake
          : SkillProfileKind.baseline,
      diagnosedAt: DateTime.parse(diagnosedAt!),
      profile: SkillProfile(
        topArea: SkillArea.values.byName(topArea),
        secondArea: SkillArea.values.byName(secondArea),
        topBehavior: topBehavior == null
            ? null
            : BehaviorCode.fromWireCode(topBehavior),
        secondBehavior: secondBehavior == null
            ? null
            : BehaviorCode.fromWireCode(secondBehavior),
        strengths: [
          for (final code in strengths)
            if (code is String) ?BehaviorCode.fromWireCode(code),
        ],
        evidence: [for (final row in evidence) ?_evidenceFromJson(row)],
      ),
    );
  }
}

DiagnosisEvidence? _evidenceFromJson(Object? row) {
  if (row is! Map) return null;
  final attemptId = row['attempt_id'];
  final code = row['code'];
  if (attemptId is! String || code is! String) return null;
  final behaviorCode = BehaviorCode.fromWireCode(code);
  if (behaviorCode == null) return null;
  return DiagnosisEvidence(attemptId: attemptId, code: behaviorCode);
}
