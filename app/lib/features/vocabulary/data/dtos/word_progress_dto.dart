import 'package:flui/core/date/local_date.dart';
import 'package:flui/features/vocabulary/domain/grade.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flui/features/vocabulary/domain/word_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_progress_dto.freezed.dart';
part 'word_progress_dto.g.dart';

/// A `word_progress` row. Dates are `yyyy-MM-dd`, timestamps UTC.
@freezed
abstract class WordProgressDto with _$WordProgressDto {
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory({
    required String wordId,
    required String state,
    required String introducedOn,
    required List<String> firstTrySuccessDays,
    required bool formRecallDone,
    required bool productionDone,
    required int ladderStep,
    String? userId,
    String? nextDueOn,
    String? lastGrade,
    DateTime? lastReviewedAt,
  }) = _WordProgressDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$WordProgressDtoFromJson(json);

  factory fromDomain(WordProgress progress, {required String userId}) =>
      WordProgressDto(
        userId: userId,
        wordId: progress.wordId,
        state: progress.state.name,
        introducedOn: progress.introducedOn.toIso(),
        firstTrySuccessDays: [
          for (final date in progress.firstTrySuccessDays.toList()..sort())
            date.toIso(),
        ],
        formRecallDone: progress.formRecallDone,
        productionDone: progress.productionDone,
        ladderStep: progress.ladderStep,
        nextDueOn: progress.nextDueOn?.toIso(),
        lastGrade: progress.lastGrade?.name,
        lastReviewedAt: progress.lastReviewedAt?.toUtc(),
      );

  const new _();

  static const columns =
      'word_id, state, introduced_on, first_try_success_days, '
      'form_recall_done, production_done, ladder_step, next_due_on, '
      'last_grade, last_reviewed_at';

  WordProgress toDomain() {
    final nextDue = nextDueOn;
    final grade = lastGrade;
    return WordProgress(
      wordId: wordId,
      state: WordState.values.byName(state),
      introducedOn: LocalDate.parse(introducedOn),
      firstTrySuccessDays: {
        for (final date in firstTrySuccessDays) LocalDate.parse(date),
      },
      formRecallDone: formRecallDone,
      productionDone: productionDone,
      ladderStep: ladderStep,
      nextDueOn: nextDue == null ? null : LocalDate.parse(nextDue),
      lastGrade: grade == null ? null : Grade.values.byName(grade),
      lastReviewedAt: lastReviewedAt,
    );
  }
}
