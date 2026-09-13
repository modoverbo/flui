import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/daily/domain/daily_gate.dart';
import 'package:flui/features/daily/domain/daily_session_repository.dart';
import 'package:flui/features/daily/presentation/providers/learning_data_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:flui/features/daily/domain/daily_gate.dart';

part 'daily_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
DailySessionRepository dailySessionRepository(Ref ref) {
  throw UnimplementedError(
    'dailySessionRepositoryProvider must be overridden.',
  );
}

/// Id of the signed-in user, `null` while signed out or unknown.
@Riverpod(keepAlive: true)
String? currentUserId(Ref ref) =>
    ref.watch(authUserProvider.select((user) => user.value?.id));

@Riverpod(keepAlive: true)
DailyGate dailyGate(Ref ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return DailyGate.unknown;
  final today = ref.watch(clockProvider).localToday();
  return switch (ref.watch(learningDataControllerProvider(userId))) {
    AsyncValue(hasValue: true, :final value?) =>
      value.sessionOn(today) == null
          ? DailyGate.needsBudget
          : DailyGate.planned,
    AsyncError() => DailyGate.unavailable,
    _ => DailyGate.unknown,
  };
}
