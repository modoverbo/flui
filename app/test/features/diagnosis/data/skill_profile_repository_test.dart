import 'package:flui/core/error/failure.dart';
import 'package:flui/features/diagnosis/data/fake_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/data/supabase_skill_profile_repository.dart';
import 'package:flui/features/diagnosis/domain/skill_profile_repository.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';
import 'package:flui/features/training/domain/skill_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_recorder.dart';

const _profile = SkillProfile(
  topArea: SkillArea.thinking,
  secondArea: SkillArea.language,
  topBehavior: BehaviorCode.noClearStructure,
  secondBehavior: BehaviorCode.vagueWord,
  strengths: [BehaviorCode.steadyPace],
  evidence: [
    DiagnosisEvidence(attemptId: 'a1', code: BehaviorCode.noClearStructure),
  ],
);

Map<String, Object?> _row({
  String id = 's1',
  String kind = 'baseline',
  String diagnosedAt = '2026-09-14T10:00:00+00:00',
}) => {
  'id': id,
  'kind': kind,
  'top_area': 'thinking',
  'second_area': 'language',
  'top_behavior': 'no_clear_structure',
  'second_behavior': 'vague_word',
  'strengths': ['steady_pace'],
  'evidence': [
    {'attempt_id': 'a1', 'code': 'no_clear_structure'},
  ],
  'diagnosed_at': diagnosedAt,
};

void main() {
  group('FakeSkillProfileRepository', () {
    test('latest is null before any diagnosis is saved', () async {
      final repository = FakeSkillProfileRepository(currentUserId: () => 'u1');

      expect((await repository.latest()).valueOrNull, isNull);
    });

    test('the first save is a baseline', () async {
      final repository = FakeSkillProfileRepository(currentUserId: () => 'u1');

      final result = await repository.save(sessionId: 's1', profile: _profile);

      final record = result.valueOrNull!;
      expect(record.kind, SkillProfileKind.baseline);
      expect(record.id, 's1');
      expect(record.profile, _profile);
      expect((await repository.latest()).valueOrNull, record);
      expect((await repository.history()).valueOrNull, [record]);
    });

    test('a retake at least 30 days later is accepted as retake', () async {
      var now = DateTime.utc(2026);
      final repository = FakeSkillProfileRepository(
        currentUserId: () => 'u1',
        now: () => now,
      );
      await repository.save(sessionId: 's1', profile: _profile);
      now = now.add(const Duration(days: 30));

      final result = await repository.save(sessionId: 's2', profile: _profile);

      expect(result.valueOrNull!.kind, SkillProfileKind.retake);
      expect((await repository.history()).valueOrNull, hasLength(2));
    });

    test('a retake less than 30 days later is rejected', () async {
      var now = DateTime.utc(2026);
      final repository = FakeSkillProfileRepository(
        currentUserId: () => 'u1',
        now: () => now,
      );
      await repository.save(sessionId: 's1', profile: _profile);
      now = now.add(const Duration(days: 29));

      final result = await repository.save(sessionId: 's2', profile: _profile);

      expect(
        result.failureOrNull,
        const SkillProfileFailure(SkillProfileErrorCode.retakeTooSoon),
      );
    });

    test('fails without a signed-in user', () async {
      final repository = FakeSkillProfileRepository(currentUserId: () => null);

      expect((await repository.latest()).isOk, isFalse);
      expect((await repository.history()).isOk, isFalse);
      expect(
        (await repository.save(sessionId: 's1', profile: _profile)).isOk,
        isFalse,
      );
    });
  });

  group('SupabaseSkillProfileRepository', () {
    test('latest reads the newest row', () async {
      final recorder = SupabaseRecorder(respond: (_) => _row());
      addTearDown(recorder.dispose);

      final result = await SupabaseSkillProfileRepository(recorder.client)
          .latest();

      expect(result.valueOrNull!.profile, _profile);
      expect(recorder.last.url.path, '/rest/v1/skill_profiles');
      expect(
        recorder.last.url.queryParameters['order'],
        'diagnosed_at.desc.nullslast',
      );
    });

    test('save inserts the profile and returns the closed row', () async {
      final recorder = SupabaseRecorder(respond: (_) => _row());
      addTearDown(recorder.dispose);

      final result = await SupabaseSkillProfileRepository(recorder.client)
          .save(sessionId: 's1', profile: _profile);

      expect(result.isOk, isTrue);
      expect(recorder.last.method, 'POST');
      final body = recorder.bodyOf(recorder.last)! as Map<String, Object?>;
      expect(body['id'], 's1');
      expect(body['top_area'], 'thinking');
      expect(body.containsKey('kind'), isFalse);
      expect(body.containsKey('diagnosed_at'), isFalse);
    });

    test('maps a retake_too_soon trigger error to a typed failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => http.Response(
          '{"code":"23514","message":"retake_too_soon","details":null,'
          '"hint":null}',
          400,
          headers: {'content-type': 'application/json'},
        ),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSkillProfileRepository(recorder.client)
          .save(sessionId: 's2', profile: _profile);

      expect(
        result.failureOrNull,
        const SkillProfileFailure(SkillProfileErrorCode.retakeTooSoon),
      );
    });

    test('maps transport errors to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSkillProfileRepository(recorder.client)
          .latest();

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
