import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/subscription/domain/access_poller.dart';
import 'package:flui/features/subscription/domain/access_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixedClock clock;
  late List<Duration> sleeps;
  late AccessPoller poller;

  const trialing = AccessStatus(
    hasAccess: true,
    entitlementStatus: EntitlementStatus.trialing,
  );

  setUp(() {
    clock = FixedClock(DateTime(2026, 9, 13, 10));
    sleeps = [];
    poller = AccessPoller(
      clock: clock,
      sleep: (duration) async {
        sleeps.add(duration);
        clock.advance(duration);
      },
    );
  });

  Future<Result<AccessStatus>> Function() responses(
    List<Result<AccessStatus>> results,
  ) {
    var index = 0;
    return () async =>
        results[index < results.length ? index++ : results.length - 1];
  }

  test('returns immediately when access is already granted', () async {
    final outcome = await poller.waitForAccess(
      responses([const Result.ok(trialing)]),
    );

    expect(outcome, const AccessActivated(trialing));
    expect(sleeps, isEmpty);
  });

  test('polls every 2 seconds until access appears', () async {
    final outcome = await poller.waitForAccess(
      responses([
        const Result.ok(AccessStatus.none),
        const Result.err(NetworkFailure()),
        const Result.ok(trialing),
      ]),
    );

    expect(outcome, const AccessActivated(trialing));
    expect(sleeps, [const Duration(seconds: 2), const Duration(seconds: 2)]);
  });

  test('times out after 60 seconds', () async {
    var attempts = 0;
    final outcome = await poller.waitForAccess(() async {
      attempts++;
      return const Result.ok(AccessStatus.none);
    });

    expect(outcome, const AccessPollTimedOut());
    expect(attempts, 31);
    expect(clock.now(), DateTime(2026, 9, 13, 10, 1));
  });

  test('stops when cancelled', () async {
    var attempts = 0;
    final outcome = await poller.waitForAccess(() async {
      attempts++;
      return const Result.ok(AccessStatus.none);
    }, isCancelled: () => attempts >= 2);

    expect(outcome, const AccessPollCancelled());
    expect(attempts, 2);
  });
}
