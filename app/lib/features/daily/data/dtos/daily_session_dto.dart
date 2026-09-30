import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/daily/domain/daily_session.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_session_dto.freezed.dart';
part 'daily_session_dto.g.dart';

/// A `daily_sessions` row.
@freezed
abstract class DailySessionDto with _$DailySessionDto {
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory({
    required String localDate,
    required int minutes,
    required List<String> plannedWordIds,
    required List<String> reviewWordIds,
    String? userId,

    /// Always written, even as null: dropping the key from the upsert would
    /// leave yesterday's theme on a day the user planned without one.
    @JsonKey(includeIfNull: true) String? themeId,
    DateTime? completedAt,

    /// Always written, even as null: same reasoning as [themeId] — a
    /// re-plan (e.g. changing the duration) that no longer picks a
    /// training focus must not leave a stale one behind.
    @JsonKey(includeIfNull: true) String? focusArea,
    @JsonKey(includeIfNull: true) String? challengeId,
    @Default(<String>[]) List<String> wovenWordIds,
  }) = _DailySessionDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$DailySessionDtoFromJson(json);

  /// Upsert payload for the plan; `completed_at` is never overwritten here.
  factory fromDomain(DailySession session, {required String userId}) =>
      DailySessionDto(
        userId: userId,
        localDate: session.localDate.toIso(),
        minutes: session.minutes,
        plannedWordIds: session.plannedWordIds,
        reviewWordIds: session.reviewWordIds,
        themeId: session.themeId,
        focusArea: session.focusArea,
        challengeId: session.challengeId,
        wovenWordIds: session.wovenWordIds,
      );

  const new _();

  static const _baseColumns =
      'local_date, minutes, planned_word_ids, review_word_ids, theme_id, '
      'completed_at';

  /// `focus_area`/`challenge_id`/`woven_word_ids` — the U7 migration's
  /// training-plan columns, always selected and written.
  static const trainingPlanColumns = 'focus_area, challenge_id, woven_word_ids';

  static String columns() => '$_baseColumns, $trainingPlanColumns';

  DailySession toDomain() => DailySession(
    localDate: LocalDate.parse(localDate),
    minutes: minutes,
    plannedWordIds: plannedWordIds,
    reviewWordIds: reviewWordIds,
    themeId: themeId,
    completedAt: completedAt,
    focusArea: focusArea,
    challengeId: challengeId,
    wovenWordIds: wovenWordIds,
  );
}
