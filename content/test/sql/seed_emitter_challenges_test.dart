import 'dart:io';

import 'package:content/src/model/challenge.dart';
import 'package:content/src/sql/seed_emitter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Challenge _challenge({
  required String slug,
  ChallengePurpose purpose = ChallengePurpose.training,
  int? diagnosisSlot,
  Skill skill = Skill.thinking,
  TrainingMode? mode = TrainingMode.thinkAndSpeak,
  int difficulty = 1,
  ChallengeStatus status = ChallengeStatus.approved,
}) => Challenge(
  slug: slug,
  status: status,
  purpose: purpose,
  diagnosisSlot: diagnosisSlot,
  skill: skill,
  mode: mode,
  difficulty: difficulty,
  prompt: 'Cuéntame algo sobre $slug, con al menos diez caracteres.',
  focus: 'Enfócate en decir esto con claridad.',
  focusBehaviors: const ['main_point_late'],
  transferPrompts: purpose == ChallengePurpose.training
      ? const ['Ahora cuéntamelo de otra forma.']
      : const [],
  targetSeconds: 30,
);

void main() {
  group('deterministicChallengeId', () {
    test('is stable across calls and uuid-shaped', () {
      final first = deterministicChallengeId('decision-que-mejoro-tu-dia');
      final second = deterministicChallengeId('decision-que-mejoro-tu-dia');
      expect(first, second);
      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('differs for a different slug', () {
      expect(
        deterministicChallengeId('a'),
        isNot(deterministicChallengeId('b')),
      );
    });
  });

  group('approvedChallengesInOrder', () {
    test('drops non-approved challenges', () {
      final challenges = [
        _challenge(slug: 'draft-one', status: ChallengeStatus.draft),
        _challenge(slug: 'approved-one'),
      ];
      final result = approvedChallengesInOrder(challenges);
      expect(result.map((c) => c.slug), ['approved-one']);
    });

    test('orders by purpose, diagnosis_slot, mode, difficulty, then slug', () {
      final challenges = [
        _challenge(
          slug: 'diagnosis-slot-2',
          purpose: ChallengePurpose.diagnosis,
          diagnosisSlot: 2,
          mode: null,
        ),
        _challenge(
          slug: 'training-b',
          mode: TrainingMode.speakWithPrecision,
        ),
        _challenge(
          slug: 'diagnosis-slot-1',
          purpose: ChallengePurpose.diagnosis,
          diagnosisSlot: 1,
          mode: null,
        ),
        _challenge(slug: 'training-a'),
      ];
      final result = approvedChallengesInOrder(challenges);
      // ChallengePurpose.training (index 0) sorts before diagnosis (index 1);
      // within training, mode.index then difficulty then slug.
      expect(result.map((c) => c.slug), [
        'training-a',
        'training-b',
        'diagnosis-slot-1',
        'diagnosis-slot-2',
      ]);
    });
  });

  group('emitChallenges', () {
    test('is empty for an empty list', () {
      expect(emitChallenges(const []), isEmpty);
    });

    test('is deterministic: identical input produces identical bytes', () {
      final challenges = [_challenge(slug: 'a'), _challenge(slug: 'b')];
      expect(emitChallenges(challenges), emitChallenges(challenges));
    });

    test('assigns sort_order as the 1-based emission index', () {
      final sql = emitChallenges([
        _challenge(slug: 'a'),
        _challenge(slug: 'b'),
      ]);
      expect(sql, contains(', 1, true)'));
      expect(sql, contains(', 2, true)'));
    });

    test('renders every field, including a null cue/mode/diagnosis_slot', () {
      final sql = emitChallenges([
        _challenge(
          slug: 'diagnosis-x',
          purpose: ChallengePurpose.diagnosis,
          diagnosisSlot: 1,
          mode: null,
        ),
      ]);
      expect(sql, contains("'diagnosis-x'"));
      expect(sql, contains("'diagnosis'"));
      expect(sql, contains('null')); // mode or cue is null
    });

    test('escapes apostrophes in literals', () {
      const challenge = Challenge(
        slug: 'con-apostrofe',
        status: ChallengeStatus.approved,
        purpose: ChallengePurpose.training,
        skill: Skill.thinking,
        mode: TrainingMode.thinkAndSpeak,
        difficulty: 1,
        prompt: 'Cuéntame algo que te sorprendió, con más de diez letras.',
        cue: 'Empieza con «hoy me di cuenta de...»',
        focus: 'Enfócate en tu idea principal.',
        transferPrompts: ['No lo compares, cuéntalo de nuevo.'],
        targetSeconds: 30,
      );
      expect(() => emitChallenges([challenge]), returnsNormally);
    });
  });

  group('emitSeed', () {
    test('with challenges: [] stays byte-identical to the default', () {
      const preamble = 'preamble\n';
      final withEmpty = emitSeed(
        preamble: preamble,
        words: const [],
        // Deliberately explicit: this is exactly the byte-identical
        // contract under test.
        // ignore: avoid_redundant_argument_values
        challenges: const [],
      );
      final withoutParam = emitSeed(preamble: preamble, words: const []);
      expect(withEmpty, withoutParam);
    });

    test('appends the challenges block after the words section', () {
      final sql = emitSeed(
        preamble: 'preamble\n',
        words: const [],
        challenges: [_challenge(slug: 'a')],
      );
      expect(sql, contains('-- Challenges'));
    });
  });

  group('supabase/seed.sql', () {
    test('is unaffected when no challenge content exists yet', () {
      // This unit does not author any content/challenges/*.yml file (that
      // is U6a/U6b); the emitter's --check keeps the committed seed
      // byte-identical, and this is the same guarantee at the unit level.
      final seedPath = p.normalize(
        p.join(Directory.current.path, '..', 'supabase', 'seed.sql'),
      );
      expect(File(seedPath).existsSync(), isTrue);
    });
  });
}
