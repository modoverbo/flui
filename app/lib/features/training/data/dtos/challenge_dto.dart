import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge_dto.freezed.dart';
part 'challenge_dto.g.dart';

/// A `public.challenges` row (design part-3 §5).
@freezed
abstract class ChallengeDto with _$ChallengeDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required String slug,
    required String purpose,
    required String skill,
    required int difficulty,
    required String prompt,
    required String focus,
    required List<String> focusBehaviors,
    required List<String> transferPrompts,
    required int targetSeconds,
    required int sortOrder,
    int? diagnosisSlot,
    String? mode,
    String? cue,
  }) = _ChallengeDto;

  factory fromJson(Map<String, dynamic> json) => _$ChallengeDtoFromJson(json);

  const new _();

  static const columns =
      'id, slug, purpose, diagnosis_slot, skill, mode, difficulty, prompt, '
      'cue, focus, focus_behaviors, transfer_prompts, target_seconds, '
      'sort_order';

  Challenge toDomain() => Challenge(
    id: id,
    slug: slug,
    purpose: ChallengePurpose.values.byName(purpose),
    skill: Skill.values.byName(skill),
    difficulty: difficulty,
    prompt: prompt,
    focus: focus,
    focusBehaviors: [
      for (final wireCode in focusBehaviors)
        ?BehaviorCode.fromWireCode(wireCode),
    ],
    transferPrompts: transferPrompts,
    targetDuration: Duration(seconds: targetSeconds),
    sortOrder: sortOrder,
    diagnosisSlot: diagnosisSlot,
    mode: _modeFromWire(mode),
    cue: cue,
  );

  static TrainingMode? _modeFromWire(String? wireMode) => switch (wireMode) {
    'think_and_speak' => TrainingMode.thinkAndSpeak,
    'speak_with_precision' => TrainingMode.speakWithPrecision,
    'master_your_voice' => TrainingMode.masterYourVoice,
    'real_situations' => TrainingMode.realSituations,
    _ => null,
  };
}
