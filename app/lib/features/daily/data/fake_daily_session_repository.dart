import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/core/fake/fake_remote.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:flui/features/daily/domain/daily_session_repository.dart';

/// In-memory `daily_sessions`, one row per user and local date.
final class FakeDailySessionRepository
    with FakeRemote
    implements DailySessionRepository {
  new({required this.currentUserId, this.latency = Duration.zero});

  final String? Function() currentUserId;

  @override
  final Duration latency;

  final _rows = <String, Map<LocalDate, DailySession>>{};

  @override
  Future<Result<List<DailySession>>> fetchSessions() async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    final sessions = [...?_rows[userId]?.values]
      ..sort((a, b) => a.localDate.compareTo(b.localDate));
    return Result.ok(sessions);
  }

  @override
  Future<Result<void>> saveSession(DailySession session) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    final table = _rows.putIfAbsent(userId, () => {});
    final existing = table[session.localDate];
    table[session.localDate] = session.copyWith(
      completedAt: existing?.completedAt,
    );
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> completeSession({
    required LocalDate localDate,
    required DateTime completedAt,
  }) async {
    if (await simulateCall() case final failure?) return Result.err(failure);
    final userId = currentUserId();
    if (userId == null) return const Result.err(notSignedInFailure);
    final table = _rows.putIfAbsent(userId, () => {});
    final existing = table[localDate];
    if (existing != null) {
      table[localDate] = existing.copyWith(completedAt: completedAt);
    }
    return const Result.ok(null);
  }
}
