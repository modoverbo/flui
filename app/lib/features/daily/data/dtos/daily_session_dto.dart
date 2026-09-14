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
      );

  const new _();

  static const columns =
      'local_date, minutes, planned_word_ids, review_word_ids, theme_id, '
      'completed_at';

  DailySession toDomain() => DailySession(
    localDate: LocalDate.parse(localDate),
    minutes: minutes,
    plannedWordIds: plannedWordIds,
    reviewWordIds: reviewWordIds,
    themeId: themeId,
    completedAt: completedAt,
  );
}
