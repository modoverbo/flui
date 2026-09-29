import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/profile/domain/account_deletion_repository.dart';

/// In-memory [AccountDeletionRepository]: records every call and, when
/// [nextFailure] is set, fails exactly once (mirrors `FakeAuthRepository`'s
/// failure-injection pattern) before returning to success.
final class FakeAccountDeletionRepository implements AccountDeletionRepository {
  new({this.latency = Duration.zero});

  /// Artificial delay before resolving — lets tests observe the "in flight"
  /// window (e.g. a double tap landing before the first call resolves, or a
  /// tab switch/navigation away while the request is still running).
  /// Mutable so a test can set it on the instance `fakeBackendOverrides`
  /// already wired, instead of re-overriding the provider (which
  /// `AppHarness` cannot do — see its own `accountDeletion` getter).
  Duration latency;
  Failure? nextFailure;
  int callCount = 0;

  @override
  Future<Result<void>> deleteAccount() async {
    callCount++;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) return Result.err(failure);
    return const Result.ok(null);
  }
}
