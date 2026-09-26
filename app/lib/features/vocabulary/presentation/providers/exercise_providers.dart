import 'dart:math';

import 'package:flui/features/vocabulary/domain/exercises/exercise_attempt_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercise_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
ExerciseAttemptRepository exerciseAttemptRepository(Ref ref) {
  throw UnimplementedError(
    'exerciseAttemptRepositoryProvider must be overridden.',
  );
}

/// Shuffles cloze options. Tests override it with a seeded `Random`, or with
/// `null` to keep the stored order.
@Riverpod(keepAlive: true)
Random? shuffleRandom(Ref ref) => Random();
