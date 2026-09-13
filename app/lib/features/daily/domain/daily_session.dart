import 'package:flui/core/date/local_date.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_session.freezed.dart';

/// The time budget of a local day and its plan (`daily_sessions` row).
@freezed
abstract class DailySession with _$DailySession {
  const factory({
    required LocalDate localDate,
    required int minutes,

    /// New words to introduce today, in order.
    @Default(<String>[]) List<String> plannedWordIds,

    /// Reviews for today, in order (warm-up first).
    @Default(<String>[]) List<String> reviewWordIds,
    DateTime? completedAt,
  }) = _DailySession;

  const new _();

  bool get isCompleted => completedAt != null;

  bool get isEmpty => plannedWordIds.isEmpty && reviewWordIds.isEmpty;
}
