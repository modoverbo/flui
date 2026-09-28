import 'dart:convert';

import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/training/data/dtos/speaking_attempt_dto.dart';
import 'package:flui/features/training/data/fake_speaking_attempt_repository.dart';
import 'package:flui/features/training/data/supabase_speaking_attempt_repository.dart';
import 'package:flui/features/training/domain/attempt_kind.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/speaking_attempt.dart';
import 'package:flui/features/training/domain/training_context.dart';
import 'package:flui/features/training/domain/voice_metrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/learning_builders.dart';
import '../../../helpers/supabase_recorder.dart';

const _metrics = VoiceMetrics(longPauses: 1, usefulPauses: 2, fillerCount: 3);

SpeakingAttempt _attempt({
  String id = 'a1',
  AudioRetention audio = const AudioRetention.none(),
  LocalDate? milestoneWeek,
  TrainingContext context = TrainingContext.daily,
}) => SpeakingAttempt(
  id: id,
  sessionId: 's1',
  context: context,
  kind: AttemptKind.first,
  localDate: day(14),
  transcript: 'Hoy hablé de mi rutina diaria completa.',
  duration: const Duration(seconds: 22),
  metrics: _metrics,
  observations: const [
    Observation(
      code: BehaviorCode.clearMainPoint,
      source: ObservationSource.ai,
      evidence: 'Empezó con la idea principal.',
    ),
  ],
  audio: audio,
  milestoneWeek: milestoneWeek,
);

Map<String, Object?> _attemptRow(SpeakingAttempt attempt) =>
    SpeakingAttemptDto.fromDomain(attempt).toJson();

void main() {
  group('SpeakingAttemptDto', () {
    test('round-trips transcript, metrics and observations', () {
      final attempt = _attempt(
        audio: const AudioRetention.pending(),
        milestoneWeek: day(14),
      );

      final json = SpeakingAttemptDto.fromDomain(attempt).toJson();

      expect(json['audio_status'], 'pending');
      expect(json['milestone_week'], '2026-09-14');
      final roundTripped = SpeakingAttemptDto.fromJson(json).toDomain();
      expect(roundTripped, attempt);
    });

    test('drops an unknown observation code rather than throwing', () {
      final json = _attemptRow(_attempt());
      json['observations'] = [
        {'code': 'not_a_real_code', 'source': 'ai'},
      ];

      final attempt = SpeakingAttemptDto.fromJson(json).toDomain();

      expect(attempt.observations, isEmpty);
    });

    test('a stored row without path/mime degrades to none', () {
      final json = _attemptRow(_attempt());
      json['audio_status'] = 'stored';

      final attempt = SpeakingAttemptDto.fromJson(json).toDomain();

      expect(attempt.audio, const AudioRetention.none());
    });
  });

  group('FakeSpeakingAttemptRepository', () {
    test('persists a milestone-eligible attempt as pending', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => 'u1',
      );

      final result = await repository.insert(
        _attempt(audio: const AudioRetention.pending(), milestoneWeek: day(14)),
      );

      expect(result.valueOrNull!.audio, const AudioRetention.pending());
      expect(result.valueOrNull!.milestoneWeek, day(14));
      expect(repository.attemptsForCurrentUser, hasLength(1));
    });

    test(
      'persists a non-eligible attempt as none, no milestone week',
      () async {
        final repository = FakeSpeakingAttemptRepository(
          currentUserId: () => 'u1',
        );

        final result = await repository.insert(_attempt());

        expect(result.valueOrNull!.audio, const AudioRetention.none());
        expect(result.valueOrNull!.milestoneWeek, isNull);
      },
    );

    test('a second attempt claiming an already-claimed week downgrades to '
        'none, keeping its transcript and metrics', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => 'u1',
      );
      await repository.insert(
        _attempt(
          id: 'first',
          audio: const AudioRetention.pending(),
          milestoneWeek: day(14),
        ),
      );

      final second = await repository.insert(
        _attempt(
          id: 'second',
          audio: const AudioRetention.pending(),
          milestoneWeek: day(14),
        ),
      );

      final downgraded = second.valueOrNull!;
      expect(downgraded.audio, const AudioRetention.none());
      expect(downgraded.milestoneWeek, isNull);
      expect(downgraded.transcript, isNotEmpty);
      expect(downgraded.metrics, _metrics);
      expect(repository.attemptsForCurrentUser, hasLength(2));
    });

    test('two different weeks both keep their milestone', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => 'u1',
      );
      await repository.insert(
        _attempt(
          id: 'w1',
          audio: const AudioRetention.pending(),
          milestoneWeek: day(7),
        ),
      );

      final second = await repository.insert(
        _attempt(
          id: 'w2',
          audio: const AudioRetention.pending(),
          milestoneWeek: day(14),
        ),
      );

      expect(second.valueOrNull!.audio, const AudioRetention.pending());
      expect(second.valueOrNull!.milestoneWeek, day(14));
    });

    test('fails without a signed-in user', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => null,
      );

      expect((await repository.insert(_attempt())).isOk, isFalse);
    });

    test('usedChallengeIdsSince returns distinct challenge ids on/after the '
        'given date, current user only', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => 'u1',
      );
      final other = FakeSpeakingAttemptRepository(currentUserId: () => 'u2');
      await repository.insert(
        _attempt().copyWith(id: 'a1', localDate: day(10), challengeId: 'c1'),
      );
      await repository.insert(
        _attempt().copyWith(id: 'a2', localDate: day(14), challengeId: 'c1'),
      );
      await repository.insert(
        _attempt().copyWith(id: 'a3', localDate: day(14), challengeId: 'c2'),
      );
      await repository.insert(
        _attempt().copyWith(id: 'a4', localDate: day(7), challengeId: 'c3'),
      );
      await repository.insert(
        _attempt().copyWith(id: 'a5', localDate: day(14)),
      );
      await other.insert(
        _attempt().copyWith(id: 'a6', localDate: day(14), challengeId: 'c9'),
      );

      final result = await repository.usedChallengeIdsSince(day(9));

      expect(result.valueOrNull, {'c1', 'c2'});
    });

    test('usedChallengeIdsSince fails without a signed-in user', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => null,
      );

      expect((await repository.usedChallengeIdsSince(day(1))).isOk, isFalse);
    });

    test('latestDiagnosisAttempts returns only the newest diagnosis '
        "session's rows, current user only", () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => 'u1',
      );
      final other = FakeSpeakingAttemptRepository(currentUserId: () => 'u2');
      // An older, already-closed diagnosis session.
      await repository.insert(
        _attempt(context: TrainingContext.diagnosis)
            .copyWith(id: 'old-1', sessionId: 'old-session'),
      );
      // A non-diagnosis attempt in between must never be picked up.
      await repository.insert(_attempt().copyWith(id: 'daily-1'));
      // The newest (in-progress or just-finished) diagnosis session.
      await repository.insert(
        _attempt(context: TrainingContext.diagnosis)
            .copyWith(id: 'new-1', sessionId: 'new-session'),
      );
      await repository.insert(
        _attempt(context: TrainingContext.diagnosis)
            .copyWith(id: 'new-2', sessionId: 'new-session'),
      );
      await other.insert(
        _attempt(context: TrainingContext.diagnosis)
            .copyWith(id: 'other-1', sessionId: 'new-session'),
      );

      final result = await repository.latestDiagnosisAttempts();

      expect(result.valueOrNull?.map((a) => a.id).toSet(), {'new-1', 'new-2'});
    });

    test(
      'latestDiagnosisAttempts is empty with no diagnosis attempts yet',
      () async {
        final repository = FakeSpeakingAttemptRepository(
          currentUserId: () => 'u1',
        );

        final result = await repository.latestDiagnosisAttempts();

        expect(result.valueOrNull, isEmpty);
      },
    );

    test('latestDiagnosisAttempts fails without a signed-in user', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => null,
      );

      expect((await repository.latestDiagnosisAttempts()).isOk, isFalse);
    });

    test('recentAttemptsSince returns attempts on/after the date, newest '
        'first, current user only', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => 'u1',
      );
      final other = FakeSpeakingAttemptRepository(currentUserId: () => 'u2');
      await repository.insert(
        _attempt().copyWith(id: 'old', localDate: day(7)),
      );
      await repository.insert(
        _attempt().copyWith(id: 'a1', localDate: day(10)),
      );
      await repository.insert(
        _attempt().copyWith(id: 'a2', localDate: day(14)),
      );
      await other.insert(_attempt().copyWith(id: 'other', localDate: day(14)));

      final result = await repository.recentAttemptsSince(day(9));

      expect(result.valueOrNull?.map((a) => a.id), ['a2', 'a1']);
    });

    test('recentAttemptsSince fails without a signed-in user', () async {
      final repository = FakeSpeakingAttemptRepository(
        currentUserId: () => null,
      );

      expect((await repository.recentAttemptsSince(day(1))).isOk, isFalse);
    });
  });

  group('SupabaseSpeakingAttemptRepository', () {
    test('inserts the row shaped for the milestone-eligible attempt', () async {
      final attempt = _attempt(
        audio: const AudioRetention.pending(),
        milestoneWeek: day(14),
      );
      final recorder = SupabaseRecorder(respond: (_) => _attemptRow(attempt));
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .insert(attempt);

      expect(result.isOk, isTrue);
      expect(recorder.last.method, 'POST');
      expect(recorder.last.url.path, '/rest/v1/speaking_attempts');
      final body = recorder.bodyOf(recorder.last)! as Map<String, Object?>;
      expect(body['audio_status'], 'pending');
      expect(body['milestone_week'], '2026-09-14');
    });

    test(
      'retries once, downgraded, on a milestone-week uniqueness conflict',
      () async {
        final attempt = _attempt(
          audio: const AudioRetention.pending(),
          milestoneWeek: day(14),
        );
        var calls = 0;
        final recorder = SupabaseRecorder(
          respond: (_) {
            calls++;
            if (calls == 1) {
              return http.Response(
                jsonEncode({
                  'code': '23505',
                  'message':
                      'duplicate key value violates unique constraint '
                      '"speaking_attempts_user_milestone_week_idx"',
                  'details': null,
                  'hint': null,
                }),
                409,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode(
                _attemptRow(
                  attempt.copyWith(
                    audio: const AudioRetention.none(),
                    milestoneWeek: null,
                  ),
                ),
              ),
              201,
              headers: {'content-type': 'application/json'},
            );
          },
        );
        addTearDown(recorder.dispose);

        final result = await SupabaseSpeakingAttemptRepository(recorder.client)
            .insert(attempt);

        expect(recorder.requests, hasLength(2));
        final secondBody =
            recorder.bodyOf(recorder.requests.last)! as Map<String, Object?>;
        expect(secondBody['audio_status'], 'none');
        expect(secondBody['milestone_week'], isNull);
        expect(result.valueOrNull!.audio, const AudioRetention.none());
        expect(result.valueOrNull!.milestoneWeek, isNull);
      },
    );

    test('maps a non-unique-violation Postgres error normally', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied',
            'details': null,
            'hint': null,
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .insert(_attempt());

      expect(recorder.requests, hasLength(1));
      expect(result.isOk, isFalse);
    });

    test('maps transport errors to a network failure', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .insert(_attempt());

      expect(result.failureOrNull, const NetworkFailure());
    });

    test('usedChallengeIdsSince queries challenge_id filtered by local_date, '
        'RLS scopes rows to the owner', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => [
          {'challenge_id': 'c1'},
          {'challenge_id': 'c2'},
          {'challenge_id': 'c1'},
          {'challenge_id': null},
        ],
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .usedChallengeIdsSince(day(14));

      expect(result.valueOrNull, {'c1', 'c2'});
      expect(recorder.last.method, 'GET');
      expect(recorder.last.url.path, '/rest/v1/speaking_attempts');
      expect(recorder.last.url.queryParameters['select'], 'challenge_id');
      expect(recorder.last.url.queryParameters['local_date'], 'gte.2026-09-14');
    });

    test('usedChallengeIdsSince maps transport errors', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .usedChallengeIdsSince(day(1));

      expect(result.failureOrNull, const NetworkFailure());
    });

    test('latestDiagnosisAttempts first finds the newest diagnosis session '
        "id, then queries only that session's rows, newest first, capped "
        'at 3, RLS scopes rows to the owner — never a global top-3 across '
        'sessions (D38: resume/stale-row correctness)', () async {
      final rows = [
        _attemptRow(_attempt(id: 'n1', context: TrainingContext.diagnosis)),
        _attemptRow(_attempt(id: 'n2', context: TrainingContext.diagnosis)),
      ];
      final recorder = SupabaseRecorder(
        respond: (request) =>
            request.url.queryParameters['select'] == 'session_id'
            ? [
                {'session_id': 'newest-session'},
              ]
            : rows,
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .latestDiagnosisAttempts();

      expect(result.valueOrNull?.map((a) => a.id), ['n1', 'n2']);
      expect(recorder.requests, hasLength(2));

      final sessionQuery = recorder.requests.first;
      expect(sessionQuery.method, 'GET');
      expect(sessionQuery.url.path, '/rest/v1/speaking_attempts');
      expect(sessionQuery.url.queryParameters['select'], 'session_id');
      expect(sessionQuery.url.queryParameters['context'], 'eq.diagnosis');
      expect(
        sessionQuery.url.queryParameters['order'],
        'created_at.desc.nullslast',
      );
      expect(sessionQuery.url.queryParameters['limit'], '1');

      final rowsQuery = recorder.requests.last;
      expect(rowsQuery.method, 'GET');
      expect(rowsQuery.url.path, '/rest/v1/speaking_attempts');
      expect(rowsQuery.url.queryParameters['context'], 'eq.diagnosis');
      expect(rowsQuery.url.queryParameters['session_id'], 'eq.newest-session');
      expect(
        rowsQuery.url.queryParameters['order'],
        'created_at.desc.nullslast',
      );
      expect(rowsQuery.url.queryParameters['limit'], '3');
    });

    test('latestDiagnosisAttempts is empty when no diagnosis session exists '
        'yet — never queries the second time', () async {
      final recorder = SupabaseRecorder(respond: (_) => <Object?>[]);
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .latestDiagnosisAttempts();

      expect(result.valueOrNull, isEmpty);
      expect(recorder.requests, hasLength(1));
    });

    test('latestDiagnosisAttempts maps transport errors', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .latestDiagnosisAttempts();

      expect(result.failureOrNull, const NetworkFailure());
    });

    test('recentAttemptsSince queries every column filtered by local_date, '
        'newest first, RLS scopes rows to the owner', () async {
      final rows = [
        _attemptRow(_attempt(id: 'a2')),
        _attemptRow(_attempt()),
      ];
      final recorder = SupabaseRecorder(respond: (_) => rows);
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .recentAttemptsSince(day(14));

      expect(result.valueOrNull?.map((a) => a.id), ['a2', 'a1']);
      expect(recorder.last.method, 'GET');
      expect(recorder.last.url.path, '/rest/v1/speaking_attempts');
      expect(recorder.last.url.queryParameters['local_date'], 'gte.2026-09-14');
      expect(
        recorder.last.url.queryParameters['order'],
        'created_at.desc.nullslast',
      );
    });

    test('recentAttemptsSince maps transport errors', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => throw http.ClientException('offline'),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseSpeakingAttemptRepository(recorder.client)
          .recentAttemptsSince(day(1));

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
