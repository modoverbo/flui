import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/profile/domain/streak_repair_repository.dart';

/// In-memory `streak_repairs`, per user.
final class FakeStreakRepairRepository
    with FakeRemote
    implements StreakRepairRepository {
  new({required this.currentUserId, this.latency = Duration.zero});

  final String? Function() currentUserId;

  @override
  final Duration latency;

  final _rows = <String, Set<LocalDate>>{};

  @override
  Future<Result<List<LocalDate>>> fetchRepairs() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    return Result.ok([...?_rows[userId]]..sort());
  }

  @override
  Future<Result<void>> repairDay(LocalDate date) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    _rows.putIfAbsent(userId, () => {}).add(date);
    return const Result.ok(null);
  }
}
