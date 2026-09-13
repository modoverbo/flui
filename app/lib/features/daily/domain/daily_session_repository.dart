import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';
import 'package:flui/features/daily/domain/daily_session.dart';

/// The signed-in user's `daily_sessions`.
abstract interface class DailySessionRepository {
  /// All sessions, oldest first.
  Future<Result<List<DailySession>>> fetchSessions();

  /// Inserts or updates the budget and plan of `session.localDate`. Keeps an
  /// existing `completed_at`.
  Future<Result<void>> saveSession(DailySession session);

  Future<Result<void>> completeSession({
    required LocalDate localDate,
    required DateTime completedAt,
  });
}
