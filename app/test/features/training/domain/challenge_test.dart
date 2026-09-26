import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flutter_test/flutter_test.dart';

// Plain unit test, no `flutter_test` widget harness: proves the training
// domain model is pure Dart, independent of Flutter/Riverpod/Supabase.
void main() {
  group('Skill', () {
    test('has exactly the three skills', () {
      expect(Skill.values, [Skill.thinking, Skill.language, Skill.voice]);
    });
  });

  group('SkillArea', () {
    test('fluency is an observable sub-area of voice', () {
      expect(SkillArea.fluency.skill, Skill.voice);
      expect(SkillArea.voice.skill, Skill.voice);
      expect(SkillArea.thinking.skill, Skill.thinking);
      expect(SkillArea.language.skill, Skill.language);
    });
  });

  group('TrainingMode', () {
    test('has the four training modes', () {
      expect(TrainingMode.values, [
        TrainingMode.thinkAndSpeak,
        TrainingMode.speakWithPrecision,
        TrainingMode.masterYourVoice,
        TrainingMode.realSituations,
      ]);
    });
  });

  group('ChallengePurpose', () {
    test('has training and diagnosis', () {
      expect(ChallengePurpose.values, [
        ChallengePurpose.training,
        ChallengePurpose.diagnosis,
      ]);
    });
  });

  group('TrainingContext', () {
    test('includes quick practice (decision #450.3, D33)', () {
      expect(TrainingContext.values, [
        TrainingContext.diagnosis,
        TrainingContext.daily,
        TrainingContext.lab,
        TrainingContext.word,
        TrainingContext.quick,
      ]);
    });
  });

  group('AttemptKind', () {
    test('has first, repeat, transfer', () {
      expect(AttemptKind.values, [
        AttemptKind.first,
        AttemptKind.repeat,
        AttemptKind.transfer,
      ]);
    });
  });

  group('Polarity', () {
    test('has strength and opportunity', () {
      expect(Polarity.values, [Polarity.strength, Polarity.opportunity]);
    });
  });

  group('Challenge', () {
    Challenge buildChallenge({int? diagnosisSlot, TrainingMode? mode}) =>
        Challenge(
          id: 'challenge-1',
          slug: 'organiza-tu-idea',
          purpose: diagnosisSlot != null
              ? ChallengePurpose.diagnosis
              : ChallengePurpose.training,
          skill: Skill.thinking,
          difficulty: 1,
          prompt: 'Cuéntame una decisión que tomaste esta semana.',
          focus: 'Estructura tu respuesta con inicio, desarrollo y cierre.',
          focusBehaviors: const [BehaviorCode.noClearStructure],
          transferPrompts: const ['Ahora cuéntame el resultado.'],
          targetDuration: const Duration(seconds: 30),
          sortOrder: 1,
          diagnosisSlot: diagnosisSlot,
          mode: mode,
        );

    test('is constructible and comparable with no infra dependency', () {
      final a = buildChallenge(mode: TrainingMode.thinkAndSpeak);
      final b = buildChallenge(mode: TrainingMode.thinkAndSpeak);
      final differentSlot = buildChallenge(diagnosisSlot: 1);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentSlot));
    });

    test('carries optional diagnosis slot and training mode', () {
      final training = buildChallenge(mode: TrainingMode.realSituations);
      final diagnosis = buildChallenge(diagnosisSlot: 2);

      expect(training.mode, TrainingMode.realSituations);
      expect(training.diagnosisSlot, isNull);
      expect(diagnosis.diagnosisSlot, 2);
      expect(diagnosis.purpose, ChallengePurpose.diagnosis);
    });
  });
}
