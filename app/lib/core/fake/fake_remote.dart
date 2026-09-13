import 'package:flui/core/error/failure.dart';

/// Shared behavior of in-memory repositories (`BACKEND=fake` and tests):
/// optional latency and a failure returned once by the next call.
mixin FakeRemote {
  Duration get latency;

  /// Returned once by the next call, then cleared.
  Failure? nextFailure;

  /// Waits for [latency] and returns the queued failure, if any.
  Future<Failure?> simulateCall() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = nextFailure;
    nextFailure = null;
    return failure;
  }
}

/// Returned when a user-scoped repository is used while signed out.
const notSignedInFailure = UnexpectedFailure('not signed in');
