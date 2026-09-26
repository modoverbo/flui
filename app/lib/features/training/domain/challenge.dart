import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge.freezed.dart';

/// Whether a [Challenge] is used for the 3-slot diagnosis or for ordinary
/// training (HOY, ENTRENAR, PALABRAS, quick practice).
enum ChallengePurpose { training, diagnosis }

/// A published prompt the training loop asks the user to speak to.
///
/// Pure Dart (no Flutter/Riverpod/Supabase dependency): server-resolved and
/// seeded from `content/challenges/*.yml` (design D18, D19).
@freezed
abstract class Challenge with _$Challenge {
  const factory({
    required String id,
    required String slug,
    required ChallengePurpose purpose,
    required Skill skill,
    required int difficulty,
    required String prompt,
    required String focus,
    required List<BehaviorCode> focusBehaviors,
    required List<String> transferPrompts,
    required Duration targetDuration,
    required int sortOrder,
    int? diagnosisSlot,
    TrainingMode? mode,
    String? cue,
  }) = _Challenge;
}
