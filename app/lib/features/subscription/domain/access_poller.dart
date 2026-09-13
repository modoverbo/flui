import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:meta/meta.dart';

@immutable
sealed class AccessPollOutcome {
  const new();
}

@immutable
final class AccessActivated extends AccessPollOutcome {
  const new(this.status);

  final AccessStatus status;

  @override
  bool operator ==(Object other) =>
      other is AccessActivated && other.status == status;

  @override
  int get hashCode => Object.hash(AccessActivated, status);
}

@immutable
final class AccessPollTimedOut extends AccessPollOutcome {
  const new();

  @override
  bool operator ==(Object other) => other is AccessPollTimedOut;

  @override
  int get hashCode => (AccessPollTimedOut).hashCode;
}

@immutable
final class AccessPollCancelled extends AccessPollOutcome {
  const new();

  @override
  bool operator ==(Object other) => other is AccessPollCancelled;

  @override
  int get hashCode => (AccessPollCancelled).hashCode;
}

/// Waits for the Whop webhook to grant access after the checkout redirect.
///
/// The webhook can arrive after the user is back, so the return screen asks
/// `my_access()` every [interval] until [timeout] (docs/architecture.md §3).
/// Failed requests are retried on the next tick.
final class AccessPoller {
  const new({
    required this.clock,
    required this.sleep,
    this.interval = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 60),
  });

  final Clock clock;
  final Sleep sleep;
  final Duration interval;
  final Duration timeout;

  Future<AccessPollOutcome> waitForAccess(
    Future<Result<AccessStatus>> Function() fetchAccess, {
    bool Function()? isCancelled,
  }) async {
    final cancelled = isCancelled ?? () => false;
    final deadline = clock.now().add(timeout);

    while (true) {
      if (cancelled()) return const AccessPollCancelled();
      final result = await fetchAccess();
      if (cancelled()) return const AccessPollCancelled();

      if (result case Ok(:final value) when value.hasAccess) {
        return AccessActivated(value);
      }
      if (!clock.now().isBefore(deadline)) return const AccessPollTimedOut();
      await sleep(interval);
    }
  }
}
