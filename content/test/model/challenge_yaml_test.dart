import 'package:content/src/model/challenge.dart';
import 'package:content/src/model/challenge_yaml.dart';
import 'package:content/src/model/yaml_map.dart';
import 'package:test/test.dart';

/// A valid training challenge, matching design part-2 §1.1's example.
const _validTrainingYaml = '''
slug: decision-que-mejoro-tu-dia
status: approved
purpose: training
diagnosis_slot: null
skill: thinking
mode: think_and_speak
difficulty: 1
prompt: "Cuéntame una decisión pequeña que mejoró tu día."
cue: "Empieza por la decisión y luego di qué cambió."
focus: "Di tu idea principal en la primera frase."
focus_behaviors: ["main_point_late"]
transfer_prompts:
  - "Ahora cuéntame una decisión que cambiarías si pudieras."
target_seconds: 30
''';

/// A valid diagnosis challenge: no `mode`, a `diagnosis_slot`, and no
/// transfer prompts (allowed for diagnosis per the schema).
const _validDiagnosisYaml = '''
slug: cuentame-tu-semana
status: approved
purpose: diagnosis
diagnosis_slot: 1
skill: voice
mode: null
difficulty: 1
prompt: "Cuéntame cómo fue tu semana."
cue: null
focus: "Habla con un ritmo constante, sin apurarte."
focus_behaviors: []
transfer_prompts: []
target_seconds: 30
''';

Map<String, Object?> _parse(String yaml) =>
    loadYamlAsPlain(yaml)! as Map<String, Object?>;

void main() {
  group('Challenge.fromMap', () {
    test('reads every field of a valid training challenge', () {
      final challenge = Challenge.fromMap(_parse(_validTrainingYaml));

      expect(challenge.slug, 'decision-que-mejoro-tu-dia');
      expect(challenge.status, ChallengeStatus.approved);
      expect(challenge.purpose, ChallengePurpose.training);
      expect(challenge.diagnosisSlot, isNull);
      expect(challenge.skill, Skill.thinking);
      expect(challenge.mode, TrainingMode.thinkAndSpeak);
      expect(challenge.difficulty, 1);
      expect(
        challenge.prompt,
        'Cuéntame una decisión pequeña que mejoró tu día.',
      );
      expect(challenge.cue, 'Empieza por la decisión y luego di qué cambió.');
      expect(challenge.focus, 'Di tu idea principal en la primera frase.');
      expect(challenge.focusBehaviors, ['main_point_late']);
      expect(challenge.transferPrompts, [
        'Ahora cuéntame una decisión que cambiarías si pudieras.',
      ]);
      expect(challenge.targetSeconds, 30);
    });

    test('reads a valid diagnosis challenge with no mode/transfer prompts', () {
      final challenge = Challenge.fromMap(_parse(_validDiagnosisYaml));

      expect(challenge.purpose, ChallengePurpose.diagnosis);
      expect(challenge.diagnosisSlot, 1);
      expect(challenge.mode, isNull);
      expect(challenge.cue, isNull);
      expect(challenge.transferPrompts, isEmpty);
      expect(challenge.focusBehaviors, isEmpty);
    });

    test('throws FormatException when a required field is missing', () {
      final map = _parse(_validTrainingYaml)..remove('prompt');

      expect(() => Challenge.fromMap(map), throwsFormatException);
    });

    test('throws FormatException on an invalid enum value', () {
      final map = _parse(_validTrainingYaml)..['purpose'] = 'not_a_purpose';

      expect(() => Challenge.fromMap(map), throwsFormatException);
    });

    test('throws FormatException on an invalid mode value', () {
      final map = _parse(_validTrainingYaml)..['mode'] = 'not_a_mode';

      expect(() => Challenge.fromMap(map), throwsFormatException);
    });
  });

  group('writeChallengeYaml', () {
    test(
      'emits keys in the fixed canonical order regardless of input order',
      () {
        final map = {
          'target_seconds': 30,
          'slug': 'decision-que-mejoro-tu-dia',
          'status': 'approved',
          'purpose': 'training',
          'diagnosis_slot': null,
          'skill': 'thinking',
          'mode': 'think_and_speak',
          'difficulty': 1,
          'prompt': 'Cuéntame una decisión pequeña que mejoró tu día.',
          'cue': 'Empieza por la decisión y luego di qué cambió.',
          'focus': 'Di tu idea principal en la primera frase.',
          'focus_behaviors': ['main_point_late'],
          'transfer_prompts': [
            'Ahora cuéntame una decisión que cambiarías si pudieras.',
          ],
        };

        final yaml = writeChallengeYaml(map);
        final keysInOrder = yaml
            .split('\n')
            .where((line) => line.isNotEmpty && !line.startsWith('  '))
            .map((line) => line.split(':').first)
            .toList();

        expect(keysInOrder, challengeKeyOrder);
      },
    );

    test('round-trips through the parser back into an equal Challenge', () {
      final original = Challenge.fromMap(_parse(_validTrainingYaml));
      final rendered = writeChallengeYaml(_parse(_validTrainingYaml));
      final reparsed = Challenge.fromMap(_parse(rendered));

      expect(reparsed.slug, original.slug);
      expect(reparsed.mode, original.mode);
      expect(reparsed.focusBehaviors, original.focusBehaviors);
      expect(reparsed.transferPrompts, original.transferPrompts);
    });

    test('writes an empty list as []', () {
      final yaml = writeChallengeYaml(_parse(_validDiagnosisYaml));

      expect(yaml, contains('focus_behaviors: []'));
      expect(yaml, contains('transfer_prompts: []'));
    });
  });
}
