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
  });
}
