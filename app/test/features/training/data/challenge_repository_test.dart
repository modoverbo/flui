import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/training/data/dtos/challenge_dto.dart';
import 'package:flui/features/training/data/fake_challenge_repository.dart';
import 'package:flui/features/training/data/supabase_challenge_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/training_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_recorder.dart';

Challenge _challenge({
  String id = 'c1',
  ChallengePurpose purpose = ChallengePurpose.training,
  Skill skill = Skill.thinking,
  TrainingMode? mode = TrainingMode.thinkAndSpeak,
  int difficulty = 1,
  int sortOrder = 1,
  int? diagnosisSlot,
}) => Challenge(
  id: id,
  slug: 'slug-$id',
  purpose: purpose,
  skill: skill,
  mode: mode,
  difficulty: difficulty,
  prompt: 'Cuéntame algo, en detalle.',
  focus: 'Ordena tus ideas.',
  focusBehaviors: const [BehaviorCode.noClearStructure],
  transferPrompts: const ['Ahora cuéntame otra cosa.'],
  targetDuration: const Duration(seconds: 20),
  sortOrder: sortOrder,
  diagnosisSlot: diagnosisSlot,
);

Map<String, Object?> _challengeRow({
  String id = 'row-1',
  String purpose = 'diagnosis',
  int? diagnosisSlot = 2,
  String? mode,
  int sortOrder = 4,
}) => {
  'id': id,
  'slug': 'algo-$id',
  'purpose': purpose,
  'diagnosis_slot': diagnosisSlot,
  'skill': 'language',
  'mode': mode,
  'difficulty': 2,
  'prompt': 'Describe tu lugar favorito.',
  'cue': 'Sé exacto.',
  'focus': 'Precisión de vocabulario.',
  'focus_behaviors': ['vague_word', 'precise_word'],
  'transfer_prompts': ['Ahora describe otra cosa.'],
  'target_seconds': 30,
  'sort_order': sortOrder,
};

void main() {
  group('ChallengeDto', () {
    test('maps a published row to a Challenge, including mode/slot', () {
      final challenge = ChallengeDto.fromJson(_challengeRow()).toDomain();

      expect(challenge.purpose, ChallengePurpose.diagnosis);
      expect(challenge.skill, Skill.language);
      expect(challenge.diagnosisSlot, 2);
      expect(challenge.mode, isNull);
      expect(challenge.focusBehaviors, [
        BehaviorCode.vagueWord,
        BehaviorCode.preciseWord,
      ]);
      expect(challenge.targetDuration, const Duration(seconds: 30));
    });

    test('maps a training-mode wire value to TrainingMode', () {
      final challenge = ChallengeDto.fromJson(
        _challengeRow(
          purpose: 'training',
          diagnosisSlot: null,
          mode: 'speak_with_precision',
        ),
      ).toDomain();

      expect(challenge.mode, TrainingMode.speakWithPrecision);
    });

    test('drops an unknown focus-behavior wire code rather than throwing', () {
      final row = _challengeRow()
        ..['focus_behaviors'] = ['vague_word', 'not_a_real_code'];

      final challenge = ChallengeDto.fromJson(row).toDomain();

      expect(challenge.focusBehaviors, [BehaviorCode.vagueWord]);
    });
  });

  group('FakeChallengeRepository', () {
    test('serves the given challenges sorted by sortOrder', () async {
      final repository = FakeChallengeRepository(
        challenges: [
          _challenge(id: 'b', sortOrder: 2),
          _challenge(id: 'a'),
        ],
      );

      final result = await repository.fetchCatalog();

      expect(result.valueOrNull!.map((c) => c.id), ['a', 'b']);
    });

    test(
      'holds challenges filterable by purpose/skill/mode/difficulty',
      () async {
        final diagnosis = _challenge(
          id: 'd1',
          purpose: ChallengePurpose.diagnosis,
          skill: Skill.voice,
          mode: null,
          diagnosisSlot: 1,
        );
        final training = _challenge(
          id: 't1',
          skill: Skill.language,
          mode: TrainingMode.speakWithPrecision,
          difficulty: 3,
          sortOrder: 2,
        );
        final repository = FakeChallengeRepository(
          challenges: [diagnosis, training],
        );

        final challenges = (await repository.fetchCatalog()).valueOrNull!;

        expect(
          challenges.where((c) => c.purpose == ChallengePurpose.diagnosis),
          [diagnosis],
        );
        expect(
          challenges.where(
            (c) => c.skill == Skill.language && c.difficulty == 3,
          ),
          [training],
        );
        expect(
          challenges.where((c) => c.mode == TrainingMode.speakWithPrecision),
          [training],
        );
      },
    );

    test('returns a queued failure once', () async {
      final repository = FakeChallengeRepository(challenges: [_challenge()])
        ..nextFailure = const NetworkFailure();

      expect(await repository.fetchCatalog(), isA<Err<List<Challenge>>>());
      expect((await repository.fetchCatalog()).isOk, isTrue);
    });
  });

  group('SupabaseChallengeRepository', () {
    test('selects only published challenges, ascending sort order', () async {
      final recorder = SupabaseRecorder(respond: (_) => [_challengeRow()]);
      addTearDown(recorder.dispose);

      final result = await SupabaseChallengeRepository(recorder.client)
          .fetchCatalog();

      expect(result.valueOrNull!.single.purpose, ChallengePurpose.diagnosis);
      final url = recorder.last.url;
      expect(url.path, '/rest/v1/challenges');
      expect(url.queryParameters['published'], 'eq.true');
      expect(url.queryParameters['order'], 'sort_order.asc.nullslast');
    });

    test('pages through a catalog past the PostgREST cap', () async {
      final recorder = SupabaseRecorder(
        respond: (request) => request.url.queryParameters['offset'] == '0'
            ? List.filled(1000, _challengeRow())
            : [_challengeRow()],
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseChallengeRepository(recorder.client)
          .fetchCatalog();

      expect(result.valueOrNull, hasLength(1001));
      expect(recorder.requests, hasLength(2));
    });

    test('maps transport errors to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseChallengeRepository(recorder.client)
          .fetchCatalog();

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
