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
    test('lists the raw, challenge-level and library-level validators', () {
      expect(ChallengeValidatorRegistry.rawValidators, isNotEmpty);
      expect(ChallengeValidatorRegistry.challengeValidators, isNotEmpty);
      expect(ChallengeValidatorRegistry.libraryValidators, isNotEmpty);
      expect(
        ChallengeValidatorRegistry.all().length,
        ChallengeValidatorRegistry.rawValidators.length +
            ChallengeValidatorRegistry.challengeValidators.length +
            ChallengeValidatorRegistry.libraryValidators.length,
      );
    });
  });

  group('UniqueChallengeSlugsValidator', () {
    const validator = UniqueChallengeSlugsValidator();

    test('passes when every slug is distinct', () {
      final a = Challenge.fromMap(_validTrainingRaw());
      final b = Challenge.fromMap(_validDiagnosisRaw());
      expect(validator.validateChallengeLibrary([a, b]), isEmpty);
    });

    test('fails when two challenges share a slug', () {
      final a = Challenge.fromMap(_validTrainingRaw());
      final b = Challenge.fromMap(
        _validTrainingRaw()..['prompt'] = 'Otra consigna diferente y válida.',
      );
      final issues = validator.validateChallengeLibrary([a, b]);
      expect(issues, isNotEmpty);
      expect(issues.first.isBlocking, isTrue);
    });
  });

  group('DiagnosisSlotCoverageValidator', () {
    const validator = DiagnosisSlotCoverageValidator();

    Challenge diagnosisAt(int slot, {String status = 'approved'}) =>
        Challenge.fromMap(
          _validDiagnosisRaw()
            ..['slug'] = 'diagnostico-slot-$slot-${status.hashCode}'
            ..['diagnosis_slot'] = slot
            ..['status'] = status,
        );

    test('blocks a slot with zero approved challenges', () {
      final challenges = [diagnosisAt(1), diagnosisAt(1), diagnosisAt(2)];
      final issues = validator.validateChallengeLibrary(challenges);
      expect(
        issues.any((i) => i.isBlocking && i.location.contains('[3]')),
        isTrue,
        reason: issues.map((i) => i.toString()).join('\n'),
      );
    });

    test('warns (not blocks) a slot with exactly one approved challenge', () {
      final challenges = [
        diagnosisAt(1),
        diagnosisAt(2),
        diagnosisAt(2),
        diagnosisAt(3),
        diagnosisAt(3),
      ];
      final issues = validator.validateChallengeLibrary(challenges);
      final slot1 = issues.where((i) => i.location.contains('[1]'));
      expect(slot1, isNotEmpty);
      expect(slot1.every((i) => !i.isBlocking), isTrue);
      expect(issues.any((i) => i.location.contains('[2]')), isFalse);
      expect(issues.any((i) => i.location.contains('[3]')), isFalse);
    });

    test('a draft challenge does not count toward coverage', () {
      final challenges = [
        diagnosisAt(1, status: 'draft'),
        diagnosisAt(2),
        diagnosisAt(2),
        diagnosisAt(3),
        diagnosisAt(3),
      ];
      final issues = validator.validateChallengeLibrary(challenges);
      expect(
        issues.any((i) => i.isBlocking && i.location.contains('[1]')),
        isTrue,
      );
    });

    test('passes with 2 approved challenges in every slot', () {
      final challenges = [
        diagnosisAt(1),
        diagnosisAt(1),
        diagnosisAt(2),
        diagnosisAt(2),
        diagnosisAt(3),
        diagnosisAt(3),
      ];
      expect(validator.validateChallengeLibrary(challenges), isEmpty);
    });
  });

  group('TrainingModeCoverageValidator', () {
    const validator = TrainingModeCoverageValidator();

    Challenge trainingAt(
      TrainingMode mode,
      int difficulty, {
      String status = 'approved',
    }) => Challenge.fromMap(
      _validTrainingRaw()
        ..['slug'] = 'entreno-${mode.wireName}-$difficulty-${status.hashCode}'
        ..['mode'] = mode.wireName
        ..['difficulty'] = difficulty
        ..['status'] = status,
    );

    test('blocks a mode missing an approved difficulty-1 challenge', () {
      final challenges = [
        trainingAt(TrainingMode.thinkAndSpeak, 2),
        trainingAt(TrainingMode.thinkAndSpeak, 3),
      ];
      final issues = validator.validateChallengeLibrary(challenges);
      expect(
        issues.any(
          (i) =>
              i.isBlocking &&
              i.location.contains('think_and_speak') &&
              i.location.contains('[1]'),
        ),
        isTrue,
        reason: issues.map((i) => i.toString()).join('\n'),
      );
    });

    test('warns (not blocks) a mode missing difficulty 2 or 3', () {
      // Every other mode is fully covered so only speak_with_precision's
      // gaps show up in this assertion.
      final challenges = [
        trainingAt(TrainingMode.thinkAndSpeak, 1),
        trainingAt(TrainingMode.thinkAndSpeak, 2),
        trainingAt(TrainingMode.thinkAndSpeak, 3),
        trainingAt(TrainingMode.speakWithPrecision, 1),
        trainingAt(TrainingMode.masterYourVoice, 1),
        trainingAt(TrainingMode.masterYourVoice, 2),
        trainingAt(TrainingMode.masterYourVoice, 3),
        trainingAt(TrainingMode.realSituations, 1),
        trainingAt(TrainingMode.realSituations, 2),
        trainingAt(TrainingMode.realSituations, 3),
      ];
      final issues = validator
          .validateChallengeLibrary(challenges)
          .where((i) => i.location.contains('speak_with_precision'))
          .toList();
      expect(issues.length, 2);
      expect(issues.every((i) => !i.isBlocking), isTrue);
    });

    test('passes a fully covered mode', () {
      final challenges = [
        trainingAt(TrainingMode.masterYourVoice, 1),
        trainingAt(TrainingMode.masterYourVoice, 2),
        trainingAt(TrainingMode.masterYourVoice, 3),
      ];
      final issues = validator.validateChallengeLibrary(challenges);
      expect(
        issues.where((i) => i.location.contains('master_your_voice')),
        isEmpty,
      );
    });
  });

  group('ChallengeBrandValidator', () {
    const validator = ChallengeBrandValidator();

    test('passes clean training and diagnosis challenges', () {
      expect(
        validator.validateChallenge(Challenge.fromMap(_validTrainingRaw())),
        isEmpty,
      );
      expect(
        validator.validateChallenge(Challenge.fromMap(_validDiagnosisRaw())),
        isEmpty,
      );
    });

    test('fails on a banned school-vocabulary word in the prompt', () {
      final challenge = Challenge.fromMap(
        _validTrainingRaw()
          ..['prompt'] = 'Cuéntame sobre tu examen favorito de la escuela.',
      );
      final issues = validator.validateChallenge(challenge);
      expect(issues, isNotEmpty);
      expect(issues.first.location, 'prompt');
    });

    test('fails when the focus addresses the learner as "usted"', () {
      final challenge = Challenge.fromMap(
        _validTrainingRaw()..['focus'] = 'Cuente usted su idea con calma.',
      );
      final issues = validator.validateChallenge(challenge);
      expect(issues, isNotEmpty);
    });

    test('fails on a regional term in a transfer prompt', () {
      final challenge = Challenge.fromMap(
        _validTrainingRaw()
          ..['transfer_prompts'] = ['Cuéntame cómo fue tu día en el curro.'],
      );
      final issues = validator.validateChallenge(challenge);
      expect(issues, isNotEmpty);
      expect(issues.first.location, 'transfer_prompts[0]');
    });

    test('fails on a sensitive topic in the cue', () {
      final challenge = Challenge.fromMap(
        _validTrainingRaw()..['cue'] = 'Habla de las elecciones de tu país.',
      );
      final issues = validator.validateChallenge(challenge);
      expect(issues, isNotEmpty);
    });

    test('fails on a straight double quote (typography)', () {
      final challenge = Challenge.fromMap(
        _validTrainingRaw()..['prompt'] = 'Cuéntame qué significa "tranquilo".',
      );
      final issues = validator.validateChallenge(challenge);
      expect(issues, isNotEmpty);
    });
  });
}
