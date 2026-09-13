import 'package:flui/core/date/local_date.dart';
import 'package:flui/core/error/result.dart';

/// The signed-in user's `streak_repairs`.
abstract interface class StreakRepairRepository {
  Future<Result<List<LocalDate>>> fetchRepairs();

  Future<Result<void>> repairDay(LocalDate date);
}
