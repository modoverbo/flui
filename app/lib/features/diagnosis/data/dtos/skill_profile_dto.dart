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
@freezed
abstract class SkillProfileDto with _$SkillProfileDto {
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory({
    required String id,
    required String topArea,
    required String secondArea,
    required String topBehavior,
    required String secondBehavior,
    required List<Object?> strengths,
    required List<Object?> evidence,
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
        // A complete diagnosis always yields a behavior for its top/second
        // area — DiagnosisProfiler only leaves these null when zero
        // opportunities were observed anywhere, which the caller (U14a) does
        // not attempt to persist.
        topBehavior: profile.topBehavior!.wireCode,
        secondBehavior: profile.secondBehavior!.wireCode,
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

  SkillProfileRecord toDomain() => SkillProfileRecord(
    id: id,
    kind: kind == 'retake'
        ? SkillProfileKind.retake
        : SkillProfileKind.baseline,
    diagnosedAt: DateTime.parse(diagnosedAt!),
    profile: SkillProfile(
      topArea: SkillArea.values.byName(topArea),
      secondArea: SkillArea.values.byName(secondArea),
      topBehavior: BehaviorCode.fromWireCode(topBehavior),
      secondBehavior: BehaviorCode.fromWireCode(secondBehavior),
      strengths: [
        for (final code in strengths)
          if (code is String) ?BehaviorCode.fromWireCode(code),
      ],
      evidence: [for (final row in evidence) ?_evidenceFromJson(row)],
    ),
  );
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
