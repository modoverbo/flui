import 'package:flui/core/clock/clock_providers.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/subscription/domain/access_gate.dart';
import 'package:flui/features/subscription/domain/access_poller.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flui/features/subscription/domain/checkout_launcher.dart';
import 'package:flui/features/subscription/domain/subscription_plan.dart';
import 'package:flui/features/subscription/domain/subscription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_providers.g.dart';

/// Overridden in `bootstrap.dart` (Supabase or fake) and in tests.
@Riverpod(keepAlive: true)
SubscriptionRepository subscriptionRepository(Ref ref) {
  throw UnimplementedError(
    'subscriptionRepositoryProvider must be overridden.',
  );
}

/// Overridden in `bootstrap.dart` (url_launcher or fake) and in tests.
@Riverpod(keepAlive: true)
CheckoutLauncher checkoutLauncher(Ref ref) {
  throw UnimplementedError('checkoutLauncherProvider must be overridden.');
}

@riverpod
Future<List<SubscriptionPlan>> subscriptionPlans(Ref ref) async {
  final result = await ref.watch(subscriptionRepositoryProvider).fetchPlans();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

@riverpod
AccessPoller accessPoller(Ref ref) => AccessPoller(
  clock: ref.watch(clockProvider),
  sleep: ref.watch(sleepProvider),
);

/// `my_access()` for one user. Keyed by user id so a new session never sees
/// the previous user's access.
@Riverpod(keepAlive: true)
class AccessStatusController extends _$AccessStatusController {
  @override
  Future<AccessStatus> build(String userId) async {
    final result = await ref
        .watch(subscriptionRepositoryProvider)
        .fetchAccess();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }

  /// Stores a status obtained elsewhere (for example, by the return poller).
  void publish(AccessStatus status) => state = AsyncData(status);

  /// Asks `my_access()` again, keeping the last known value on failure.
  Future<void> refresh() async {
    if (!state.hasValue) state = const AsyncLoading();
    final result = await ref.read(subscriptionRepositoryProvider).fetchAccess();
    if (!ref.mounted) return;
    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
      case Err(:final failure) when !state.hasValue:
        state = AsyncError(failure, StackTrace.current);
      case Err():
        break;
    }
  }
}

/// Access of the signed-in user, `null` while unknown or signed out.
@Riverpod(keepAlive: true)
AccessStatus? currentAccess(Ref ref) {
  final userId = ref.watch(authUserProvider.select((user) => user.value?.id));
  if (userId == null) return null;
  return ref.watch(accessStatusControllerProvider(userId)).value;
}

/// What the router needs to know about access.
@Riverpod(keepAlive: true)
AccessGate accessGate(Ref ref) {
  final userId = ref.watch(authUserProvider.select((user) => user.value?.id));
  if (userId == null) return AccessGate.unknown;
  return switch (ref.watch(accessStatusControllerProvider(userId))) {
    AsyncValue(hasValue: true, :final value?) =>
      value.hasAccess ? AccessGate.granted : AccessGate.denied,
    AsyncError() => AccessGate.error,
    _ => AccessGate.unknown,
  };
}
