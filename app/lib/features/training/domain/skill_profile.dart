import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_profile.freezed.dart';

/// One piece of supporting evidence for a [SkillProfile]: which diagnosis
/// attempt showed which behavior (design part-3 §5, the `evidence` column).
@immutable
final class DiagnosisEvidence {
  const new({required this.attemptId, required this.code});

  final String attemptId;
  final BehaviorCode code;

  @override
  bool operator ==(Object other) =>
      other is DiagnosisEvidence &&
      other.attemptId == attemptId &&
      other.code == code;

  @override
  int get hashCode => Object.hash(attemptId, code);

  @override
  String toString() => 'DiagnosisEvidence($attemptId, ${code.wireCode})';
}

/// The output of a completed diagnosis (design D8, part-3 §5
/// `skill_profiles`): one top opportunity, one second priority, and
/// strengths, all as observable behaviors — never a numeric score.
@freezed
abstract class SkillProfile with _$SkillProfile {
  const factory({
    required SkillArea topArea,
    required SkillArea secondArea,
    required List<BehaviorCode> strengths,
    required List<DiagnosisEvidence> evidence,
    BehaviorCode? topBehavior,
    BehaviorCode? secondBehavior,
  }) = _SkillProfile;
}
