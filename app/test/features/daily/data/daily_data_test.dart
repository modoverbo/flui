import 'package:flui/features/daily/data/dtos/daily_session_dto.dart';
import 'package:flui/features/daily/data/fake_daily_session_repository.dart';
import 'package:flui/features/daily/data/supabase_daily_session_repository.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/supabase_recorder.dart';

void main() {
  final session = DailySession(
    localDate: day(13),
    minutes: 10,
    plannedWordIds: const ['w1'],
    reviewWordIds: const ['w2', 'w3'],
  );

  group('DailySessionDto', () {
    test('writes the plan without completed_at', () {
      expect(DailySessionDto.fromDomain(session, userId: 'u1').toJson(), {
        'user_id': 'u1',
        'local_date': '2026-09-13',
        'minutes': 10,
        'planned_word_ids': ['w1'],
        'review_word_ids': ['w2', 'w3'],
        // Written even when null, so replanning a day without a theme (or
        // without a training focus) clears the one it had instead of
        // keeping it silently — same reasoning for both fields.
        'theme_id': null,
        'focus_area': null,
        'challenge_id': null,
        'woven_word_ids': <String>[],
      });
    });

    test('writes the theme chosen for the day', () {
      final json = DailySessionDto.fromDomain(
        session.copyWith(themeId: 't1'),
        userId: 'u1',
      ).toJson();

      expect(json['theme_id'], 't1');
    });

    test('writes the training plan (U15a, design part-3 §5)', () {
      final json = DailySessionDto.fromDomain(
        session.copyWith(
          focusArea: 'thinking',
          challengeId: 'c1',
          wovenWordIds: const ['w4', 'w5'],
        ),
        userId: 'u1',
      ).toJson();

      expect(json['focus_area'], 'thinking');
      expect(json['challenge_id'], 'c1');
      expect(json['woven_word_ids'], ['w4', 'w5']);
    });

    test('reads a completed session', () {
      final domain = DailySessionDto.fromJson({
        'local_date': '2026-09-13',
        'minutes': 20,
        'planned_word_ids': <String>[],
        'review_word_ids': ['w2'],
        'theme_id': 't1',
        'completed_at': '2026-09-13T18:30:00Z',
      }).toDomain();

      expect(domain.minutes, 20);
      expect(domain.themeId, 't1');
      expect(domain.isCompleted, isTrue);
      expect(domain.completedAt, DateTime.utc(2026, 9, 13, 18, 30));
    });

    test('reads a session planned before themes existed', () {
      final domain = DailySessionDto.fromJson({
        'local_date': '2026-09-13',
        'minutes': 20,
        'planned_word_ids': <String>[],
        'review_word_ids': ['w2'],
      }).toDomain();

      expect(domain.themeId, isNull);
    });

    test('reads a session planned before the training columns existed '
        '(flag off, or a row saved before U15a)', () {
      final domain = DailySessionDto.fromJson({
        'local_date': '2026-09-13',
        'minutes': 20,
        'planned_word_ids': <String>[],
        'review_word_ids': ['w2'],
      }).toDomain();

      expect(domain.focusArea, isNull);
      expect(domain.challengeId, isNull);
      expect(domain.wovenWordIds, isEmpty);
      expect(domain.hasTrainingPlan, isFalse);
    });

    test('round-trips the training plan', () {
      final withPlan = session.copyWith(
        focusArea: 'language',
        challengeId: 'c2',
        wovenWordIds: const ['w6'],
      );

      final roundTripped = DailySessionDto.fromJson(
        DailySessionDto.fromDomain(withPlan, userId: 'u1').toJson(),
      ).toDomain();

      expect(roundTripped.focusArea, 'language');
      expect(roundTripped.challengeId, 'c2');
      expect(roundTripped.wovenWordIds, ['w6']);
      expect(roundTripped.hasTrainingPlan, isTrue);
    });
  });

  group('FakeDailySessionRepository', () {
    test('one row per date: recomputing keeps completion', () async {
      final repository = FakeDailySessionRepository(currentUserId: () => 'a');
      await repository.saveSession(session);
      await repository.completeSession(
        localDate: day(13),
        completedAt: DateTime(2026, 9, 13, 20),
      );
      await repository.saveSession(session.copyWith(minutes: 20));
      await repository.saveSession(
        DailySession(localDate: day(12), minutes: 5),
      );

      final stored = (await repository.fetchSessions()).valueOrNull!;
      expect(stored.map((s) => s.localDate), [day(12), day(13)]);
      expect(stored.last.minutes, 20);
      expect(stored.last.isCompleted, isTrue);
    });
  });

  group('SupabaseDailySessionRepository', () {
    test('upserts on (user_id, local_date)', () async {
      final recorder = SupabaseRecorder(respond: (_) => null);
      addTearDown(recorder.dispose);

      await SupabaseDailySessionRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).saveSession(session);

      expect(recorder.last.url.path, '/rest/v1/daily_sessions');
      expect(
        recorder.last.url.queryParameters['on_conflict'],
        'user_id,local_date',
      );
      expect(recorder.bodyOf(recorder.last), isNot(contains('completed_at')));
    });

    test('completes the row of the date in UTC', () async {
      final recorder = SupabaseRecorder(respond: (_) => null);
      addTearDown(recorder.dispose);

      await SupabaseDailySessionRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).completeSession(
        localDate: day(13),
        completedAt: DateTime.utc(2026, 9, 13, 20),
      );

      expect(recorder.last.method, 'PATCH');
      expect(recorder.last.url.queryParameters['local_date'], 'eq.2026-09-13');
      expect(recorder.last.url.queryParameters['user_id'], 'eq.u1');
      expect(recorder.bodyOf(recorder.last), {
        'completed_at': '2026-09-13T20:00:00.000Z',
      });
    });
  });

  group('SupabaseDailySessionRepository — training-plan columns (U7)', () {
    test('fetchSessions also selects the training-plan columns', () async {
      final recorder = SupabaseRecorder(respond: (_) => <Object?>[]);
      addTearDown(recorder.dispose);

      await SupabaseDailySessionRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).fetchSessions();

      final select = recorder.last.url.queryParameters['select']!;
      expect(select, contains('focus_area'));
      expect(select, contains('challenge_id'));
      expect(select, contains('woven_word_ids'));
    });

    test('saveSession also upserts the training-plan keys', () async {
      final recorder = SupabaseRecorder(respond: (_) => null);
      addTearDown(recorder.dispose);

      await SupabaseDailySessionRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).saveSession(session.copyWith(focusArea: 'thinking', challengeId: 'c1'));

      final body = recorder.bodyOf(recorder.last)! as Map<String, Object?>;
      expect(body['focus_area'], 'thinking');
      expect(body['challenge_id'], 'c1');
      expect(body.containsKey('woven_word_ids'), isTrue);
    });
  });
}
