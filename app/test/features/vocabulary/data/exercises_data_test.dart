import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/features/vocabulary/data/dtos/exercise_attempt_dto.dart';
import 'package:flui/features/vocabulary/data/fake_exercise_attempt_repository.dart';
import 'package:flui/features/vocabulary/data/supabase_exercise_attempt_repository.dart';
import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/learning_builders.dart';
import '../../../helpers/supabase_recorder.dart';

void main() {
  final attempt = ExerciseAttempt(
    exerciseId: 'e1',
    wordId: 'w1',
    attempts: 3,
    revealed: true,
    grade: Grade.again,
    localDate: day(13),
    durationMs: 4200,
  );

  group('ExerciseAttemptDto', () {
    test('writes an insert row without server defaults', () {
      expect(ExerciseAttemptDto.fromDomain(attempt, userId: 'u1').toJson(), {
        'user_id': 'u1',
        'exercise_id': 'e1',
        'word_id': 'w1',
        'attempts': 3,
        'revealed': true,
        'grade': 'again',
        'local_date': '2026-09-13',
        'duration_ms': 4200,
      });
    });

    test('reads a row', () {
      final dto = ExerciseAttemptDto.fromJson({
        'exercise_id': 'e1',
        'word_id': 'w1',
        'attempts': 1,
        'revealed': false,
        'grade': 'good',
        'local_date': '2026-09-12',
        'duration_ms': null,
        'created_at': '2026-09-12T10:00:00+00:00',
      });

      final domain = dto.toDomain();
      expect(domain.grade, Grade.good);
      expect(domain.localDate, day(12));
      expect(domain.createdAt, DateTime.utc(2026, 9, 12, 10));
      expect(domain.firstTry, isTrue);
    });
  });

  group('FakeExerciseAttemptRepository', () {
    test('appends attempts per user', () async {
      var user = 'a';
      final repository = FakeExerciseAttemptRepository(
        currentUserId: () => user,
      );
      await repository.recordAttempt(attempt);
      await repository.recordAttempt(attempt.copyWith(exerciseId: 'e2'));

      final stored = (await repository.fetchAttempts()).valueOrNull!;
      expect(
        (await repository.fetchAttempts(since: attempt.localDate.addDays(1)))
            .valueOrNull,
        isEmpty,
        reason: 'the fake honours the window too',
      );
      expect(stored.map((a) => a.exerciseId), ['e1', 'e2']);
      expect(stored.first.createdAt, isNotNull);
      user = 'b';
      expect((await repository.fetchAttempts()).valueOrNull, isEmpty);
    });

    test('returns a queued failure once', () async {
      final repository = FakeExerciseAttemptRepository(currentUserId: () => 'a')
        ..nextFailure = const NetworkFailure();

      expect((await repository.recordAttempt(attempt)).isOk, isFalse);
      expect((await repository.recordAttempt(attempt)).isOk, isTrue);
    });
  });

  group('SupabaseExerciseAttemptRepository', () {
    test('inserts into exercise_attempts', () async {
      final recorder = SupabaseRecorder(respond: (_) => null);
      addTearDown(recorder.dispose);

      final result = await SupabaseExerciseAttemptRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).recordAttempt(attempt);

      expect(result.isOk, isTrue);
      expect(recorder.last.method, 'POST');
      expect(recorder.last.url.path, '/rest/v1/exercise_attempts');
      expect(recorder.bodyOf(recorder.last), containsPair('grade', 'again'));
    });

    test('reads attempts oldest first', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => [
          ExerciseAttemptDto.fromDomain(attempt, userId: 'u1').toJson(),
        ],
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseExerciseAttemptRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).fetchAttempts();

      expect(result.valueOrNull!.single.revealed, isTrue);
      expect(
        recorder.last.url.queryParameters['order'],
        'created_at.asc.nullslast',
      );
    });

    test('a date window is pushed to the server, not filtered here', () async {
      final recorder = SupabaseRecorder(respond: (_) => <Object?>[]);
      addTearDown(recorder.dispose);

      await SupabaseExerciseAttemptRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).fetchAttempts(since: LocalDate(2026, 6, 15));

      expect(recorder.last.url.queryParameters['local_date'], 'gte.2026-06-15');
    });

    test('without a window it still asks for everything', () async {
      final recorder = SupabaseRecorder(respond: (_) => <Object?>[]);
      addTearDown(recorder.dispose);

      await SupabaseExerciseAttemptRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).fetchAttempts();

      expect(
        recorder.last.url.queryParameters.containsKey('local_date'),
        isFalse,
      );
    });

    test('maps server errors', () async {
      final recorder = SupabaseRecorder(
        respond: (_) => http.Response('{"message":"boom"}', 500),
      );
      addTearDown(recorder.dispose);

      final result = await SupabaseExerciseAttemptRepository(
        recorder.client,
        currentUserId: () => 'u1',
      ).fetchAttempts();

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
