import 'package:flui/features/profile/domain/account_deletion_repository.dart';
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

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests (U22e).
@Riverpod(keepAlive: true)
AccountDeletionRepository accountDeletionRepository(Ref ref) {
  throw UnimplementedError(
    'accountDeletionRepositoryProvider must be overridden.',
  );
}
