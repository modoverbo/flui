import 'package:freezed_annotation/freezed_annotation.dart';

part 'theme.freezed.dart';

/// Which part of life a theme belongs to (`themes.family`). The "Explorar"
/// sheet groups by this.
enum ThemeFamily { trabajo, social, publico, precision, emocion }

/// What a theme is mostly made of (`themes.content_type`).
enum ThemeContentType { wordDriven, expressionDriven, mixed }

/// Whether a theme can be chosen today (`themes.status`). A theme with no
/// words behind it is `soon`: offering it would be a promise the catalog
/// cannot keep.
enum ThemeStatus { live, beta, soon }

/// A theme of the daily choice ("¿sobre qué tema?"), a `themes` row.
///
/// A theme decides which **new** word the planner may introduce and nothing
/// else: the due-review queue, the number of new slots, the "Hoy toca
/// afianzar" threshold and the review ladder are all untouched by it
/// (docs/learning-method.md §1).
@freezed
abstract class Theme with _$Theme {
  const factory({
    required String id,
    required String slug,
    required ThemeFamily family,
    required String name,

    /// One line that says what the theme is for, in the user's words.
    required String tagline,

    /// The job the user hires this theme for.
    required String jtbd,
    required ThemeContentType contentType,
    required ThemeStatus status,
    required int sortOrder,
  }) = _Theme;

  const new _();

  /// Offered in today's picker. `beta` is offered too; `soon` never is.
  bool get isOffered => status != ThemeStatus.soon;
}
