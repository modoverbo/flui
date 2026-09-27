import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/training/data/fake/seed_challenges.dart';
import 'package:flui/features/training/domain/challenge.dart';
import 'package:flui/features/training/domain/challenge_repository.dart';

/// The published challenges of `supabase/seed.sql`, in memory.
final class FakeChallengeRepository
    with FakeRemote
    implements ChallengeRepository {
  new({List<Challenge>? challenges, this.latency = Duration.zero})
    : challenges = challenges ?? seedChallenges;

  final List<Challenge> challenges;

  @override
  final Duration latency;

  @override
  Future<Result<List<Challenge>>> fetchCatalog() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    return Result.ok(
      [...challenges]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }
}
