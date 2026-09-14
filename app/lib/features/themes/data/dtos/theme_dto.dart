import 'package:flui/features/themes/domain/theme.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'theme_dto.freezed.dart';
part 'theme_dto.g.dart';

/// A `themes` row.
@freezed
abstract class ThemeDto with _$ThemeDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String id,
    required String slug,
    required String family,
    required String name,
    required String tagline,
    required String jtbd,
    required String contentType,
    required String status,
    required int sortOrder,
  }) = _ThemeDto;

  factory fromJson(Map<String, dynamic> json) => _$ThemeDtoFromJson(json);

  const new _();

  static const columns =
      'id, slug, family, name, tagline, jtbd, content_type, status, sort_order';

  Theme toDomain() => Theme(
    id: id,
    slug: slug,
    family: ThemeFamily.values.byName(family),
    name: name,
    tagline: tagline,
    jtbd: jtbd,
    contentType: switch (contentType) {
      'expression_driven' => ThemeContentType.expressionDriven,
      'mixed' => ThemeContentType.mixed,
      _ => ThemeContentType.wordDriven,
    },
    status: ThemeStatus.values.byName(status),
    sortOrder: sortOrder,
  );
}

/// A `word_themes` row, embedded in a `words` select.
@freezed
abstract class WordThemeDto with _$WordThemeDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory({
    required String themeId,
    @Default(2) int relevance,
    int? sortOrder,
  }) = _WordThemeDto;

  factory fromJson(Map<String, dynamic> json) => _$WordThemeDtoFromJson(json);

  const new _();

  static const columns = 'word_themes(theme_id, relevance, sort_order)';
}

/// Theme ids of one word, most relevant first, then by the order the theme
/// itself wants them in.
List<String> themeIdsOf(List<WordThemeDto> rows) => [
  for (final row
      in [...rows]..sort((a, b) {
        final byRelevance = b.relevance.compareTo(a.relevance);
        if (byRelevance != 0) return byRelevance;
        return (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);
      }))
    row.themeId,
];
