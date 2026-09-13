import 'package:flui/features/profile/domain/streak_repair_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
StreakRepairRepository streakRepairRepository(Ref ref) {
  throw UnimplementedError(
    'streakRepairRepositoryProvider must be overridden.',
  );
}
