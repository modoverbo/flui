import 'package:content/src/model/challenge.dart';
import 'package:content/src/validation/challenge_validators.dart';
import 'package:content/src/validation/issue.dart';
import 'package:test/test.dart';

Map<String, Object?> _validTrainingRaw() => {
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
  'target_seconds': 30,
};

Map<String, Object?> _validDiagnosisRaw() => {
  'slug': 'cuentame-tu-semana',
  'status': 'approved',
  'purpose': 'diagnosis',
  'diagnosis_slot': 1,
  'skill': 'voice',
  'mode': null,
  'difficulty': 1,
  'prompt': 'Cuéntame cómo fue tu semana.',
  'cue': null,
  'focus': 'Habla con un ritmo constante, sin apurarte.',
  'focus_behaviors': <String>[],
  'transfer_prompts': <String>[],
  'target_seconds': 30,
};

const _validator = ChallengeSchemaConformanceValidator();

List<Issue> _validate(String slug, Map<String, Object?> raw) =>
    _validator.validateRaw(slug, raw);

void main() {
  group('ChallengeSchemaConformanceValidator', () {
    test('passes a valid training challenge', () {
      final raw = _validTrainingRaw();
      expect(_validate(raw['slug']! as String, raw), isEmpty);
    });

    test('passes a valid diagnosis challenge', () {
      final raw = _validDiagnosisRaw();
      expect(_validate(raw['slug']! as String, raw), isEmpty);
    });

    test('fails when a required field is missing', () {
      final raw = _validTrainingRaw()..remove('prompt');
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.location == 'prompt'), isTrue);
    });

    test('fails on an unknown key', () {
      final raw = _validTrainingRaw()..['bogus'] = 'x';
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'bogus'), isTrue);
    });

    test('fails when the slug is not kebab-case', () {
      final raw = _validTrainingRaw()..['slug'] = 'Not_Kebab';
      final issues = _validate('Not_Kebab', raw);
      expect(issues.any((i) => i.location == 'slug'), isTrue);
    });

    test('fails when the file name does not match the declared slug', () {
      final raw = _validTrainingRaw();
      final issues = _validate('another-slug', raw);
      expect(issues.any((i) => i.location == 'slug'), isTrue);
    });

    test('fails on an invalid purpose enum value', () {
      final raw = _validTrainingRaw()..['purpose'] = 'not_a_purpose';
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'purpose'), isTrue);
    });

    test('fails when a training challenge has no mode', () {
      final raw = _validTrainingRaw()..['mode'] = null;
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'mode'), isTrue);
    });

    test('fails when a diagnosis challenge declares a mode', () {
      final raw = _validDiagnosisRaw()..['mode'] = 'think_and_speak';
      final issues = _validate('cuentame-tu-semana', raw);
      expect(issues.any((i) => i.location == 'mode'), isTrue);
    });

    test('fails when a diagnosis challenge has no diagnosis_slot', () {
      final raw = _validDiagnosisRaw()..['diagnosis_slot'] = null;
      final issues = _validate('cuentame-tu-semana', raw);
      expect(issues.any((i) => i.location == 'diagnosis_slot'), isTrue);
    });

    test('fails when a training challenge declares a diagnosis_slot', () {
      final raw = _validTrainingRaw()..['diagnosis_slot'] = 1;
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'diagnosis_slot'), isTrue);
    });

    test('fails when a training challenge has no transfer prompts', () {
      final raw = _validTrainingRaw()..['transfer_prompts'] = <String>[];
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'transfer_prompts'), isTrue);
    });

    test('allows a diagnosis challenge with no transfer prompts', () {
      final raw = _validDiagnosisRaw();
      expect(_validate('cuentame-tu-semana', raw), isEmpty);
    });

    test('fails when transfer_prompts has more than 3 items', () {
      final raw = _validTrainingRaw()
        ..['transfer_prompts'] = List.generate(4, (i) => 'prompt $i');
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'transfer_prompts'), isTrue);
    });

    test('fails when difficulty is out of range', () {
      final raw = _validTrainingRaw()..['difficulty'] = 4;
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'difficulty'), isTrue);
    });

    test('fails when target_seconds is out of range', () {
      final raw = _validTrainingRaw()..['target_seconds'] = 5;
      final issues = _validate('decision-que-mejoro-tu-dia', raw);
      expect(issues.any((i) => i.location == 'target_seconds'), isTrue);
    });

    test('fails when diagnosis_slot is out of range', () {
      final raw = _validDiagnosisRaw()..['diagnosis_slot'] = 4;
      final issues = _validate('cuentame-tu-semana', raw);
      expect(issues.any((i) => i.location == 'diagnosis_slot'), isTrue);
    });
  });

  group('FocusBehaviorsValidator', () {
    const validator = FocusBehaviorsValidator();

    test('passes a known code matching the challenge skill', () {
      final challenge = Challenge.fromMap(_validTrainingRaw());
      expect(validator.validateChallenge(challenge), isEmpty);
    });

    test('fails on an unknown wire code', () {
      final challenge = Challenge.fromMap(
        _validTrainingRaw()..['focus_behaviors'] = ['not_a_real_code'],
      );
      final issues = validator.validateChallenge(challenge);
      expect(issues, isNotEmpty);
      expect(issues.first.location, 'focus_behaviors[0]');
    });

    test('fails when the code area does not match the challenge skill', () {
      // vague_word is a language-area code; this challenge is thinking.
      final challenge = Challenge.fromMap(
        _validTrainingRaw()..['focus_behaviors'] = ['vague_word'],
      );
      final issues = validator.validateChallenge(challenge);
      expect(issues, isNotEmpty);
    });

    test('a voice-skill challenge accepts a fluency-area code', () {
      // long_pauses is a fluency-area code; fluency.skill == voice.
      final challenge = Challenge.fromMap(
        _validDiagnosisRaw()..['focus_behaviors'] = ['long_pauses'],
      );
      expect(validator.validateChallenge(challenge), isEmpty);
    });
  });

  group('ChallengeValidatorRegistry', () {
    test('lists the raw and challenge-level validators', () {
      expect(ChallengeValidatorRegistry.rawValidators, isNotEmpty);
      expect(ChallengeValidatorRegistry.challengeValidators, isNotEmpty);
      expect(
        ChallengeValidatorRegistry.all().length,
        ChallengeValidatorRegistry.rawValidators.length +
            ChallengeValidatorRegistry.challengeValidators.length,
      );
    });
  });
}
