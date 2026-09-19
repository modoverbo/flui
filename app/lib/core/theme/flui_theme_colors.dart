import 'package:flui/core/theme/flui_colors.dart';
import 'package:material_ui/material_ui.dart';

/// The five hue neighbourhoods the 28 theme colours are organised into.
/// Family reads as a colour neighbourhood; the exact hue inside it reads as
/// the theme (`docs/redesign/01-design-system.md` §1.2).
enum FluiThemeFamily { trabajo, publico, precision, social, emocion }

/// One theme's colour identity: a saturated [surface] (icons, chips,
/// progress fills, small accent surfaces), a uniform [on] colour for
/// text/icons on top of it, and a subdued [tint] for the card behind it.
@immutable
final class FluiThemeColor {
  const new({
    required this.slug,
    required this.family,
    required this.surface,
    required this.on,
    required this.tint,
  });

  /// The theme's slug in `content/themes.yml` (or `'_fallback'` for
  /// [FluiThemeColors.fallback]).
  final String slug;

  /// `null` for [FluiThemeColors.fallback], which belongs to no family.
  final FluiThemeFamily? family;

  final Color surface;
  final Color on;
  final Color tint;

  @override
  bool operator ==(Object other) =>
      other is FluiThemeColor &&
      other.slug == slug &&
      other.family == family &&
      other.surface == surface &&
      other.on == on &&
      other.tint == tint;

  @override
  int get hashCode => Object.hash(slug, family, surface, on, tint);
}

/// A saturated hue at fixed 62% saturation, solved per-hue so contrast
/// against [FluiColors.paper] lands at 4.6:1 — safe both as a filled
/// background with paper text/icons on top, and as a coloured label
/// directly on the paper page background.
FluiThemeColor _hue({
  required String slug,
  required FluiThemeFamily family,
  required Color surface,
}) => FluiThemeColor(
  slug: slug,
  family: family,
  surface: surface,
  on: FluiColors.paper,
  // mix(themeColor, paper, 12%): a 12% mix barely moves luminance off
  // paper's, so `ink` stays AAA-readable on the tint regardless of hue
  // (`01-design-system.md` §1.2).
  tint: Color.lerp(FluiColors.paper, surface, 0.12)!,
);

/// The 28 per-theme colours of `content/themes.yml`, one dedicated hue per
/// theme, independent of the neutral editorial base and the retired "skill"
/// palette (`01-design-system.md` §0, §1.2).
abstract final class FluiThemeColors {
  static final List<FluiThemeColor> all = [
    // trabajo
    _hue(
      slug: 'reuniones',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF2977AF),
    ),
    _hue(
      slug: 'entrevistas',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF3071CC),
    ),
    _hue(
      slug: 'negociacion',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF496CD4),
    ),
    _hue(
      slug: 'liderazgo-feedback',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF5C66D9),
    ),
    _hue(
      slug: 'correos-mensajes',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF6B61DA),
    ),
    _hue(
      slug: 'redaccion-ejecutiva',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF7B5CD9),
    ),
    _hue(
      slug: 'ventas',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF8B55D7),
    ),
    _hue(
      slug: 'networking',
      family: FluiThemeFamily.trabajo,
      surface: const Color(0xFF9B4BD5),
    ),

    // publico
    _hue(
      slug: 'presentaciones-oratoria',
      family: FluiThemeFamily.publico,
      surface: const Color(0xFF916C22),
    ),
    _hue(
      slug: 'persuasion-storytelling',
      family: FluiThemeFamily.publico,
      surface: const Color(0xFF82721F),
    ),
    _hue(
      slug: 'redes-sociales',
      family: FluiThemeFamily.publico,
      surface: const Color(0xFF76761C),
    ),
    _hue(
      slug: 'docencia',
      family: FluiThemeFamily.publico,
      surface: const Color(0xFF6A791C),
    ),
    _hue(
      slug: 'medios-entrevistas',
      family: FluiThemeFamily.publico,
      surface: const Color(0xFF5C7C1D),
    ),

    // precision
    _hue(
      slug: 'matices-precision',
      family: FluiThemeFamily.precision,
      surface: const Color(0xFF1E7F77),
    ),
    _hue(
      slug: 'conectores-estructura',
      family: FluiThemeFamily.precision,
      surface: const Color(0xFF1F7E86),
    ),
    _hue(
      slug: 'paronimos',
      family: FluiThemeFamily.precision,
      surface: const Color(0xFF247B98),
    ),

    // social
    _hue(
      slug: 'elogio-reconocimiento',
      family: FluiThemeFamily.social,
      surface: const Color(0xFFCE307F),
    ),
    _hue(
      slug: 'conversacion-cotidiana',
      family: FluiThemeFamily.social,
      surface: const Color(0xFFCF346A),
    ),
    _hue(
      slug: 'humor',
      family: FluiThemeFamily.social,
      surface: const Color(0xFFD03756),
    ),
    _hue(
      slug: 'citas',
      family: FluiThemeFamily.social,
      surface: const Color(0xFFD13941),
    ),
    _hue(
      slug: 'amistad',
      family: FluiThemeFamily.social,
      surface: const Color(0xFFCD4030),
    ),
    _hue(
      slug: 'small-talk',
      family: FluiThemeFamily.social,
      surface: const Color(0xFFBD512C),
    ),
    _hue(
      slug: 'familia-crianza',
      family: FluiThemeFamily.social,
      surface: const Color(0xFFAC5D28),
    ),

    // emocion
    _hue(
      slug: 'conflicto-desacuerdo',
      family: FluiThemeFamily.emocion,
      surface: const Color(0xFFAD3DD2),
    ),
    _hue(
      slug: 'conversaciones-dificiles',
      family: FluiThemeFamily.emocion,
      surface: const Color(0xFFBB2FC8),
    ),
    _hue(
      slug: 'decir-que-no',
      family: FluiThemeFamily.emocion,
      surface: const Color(0xFFC22EB6),
    ),
    _hue(
      slug: 'empatia-escucha',
      family: FluiThemeFamily.emocion,
      surface: const Color(0xFFC82FA1),
    ),
    _hue(
      slug: 'pedir-disculparse',
      family: FluiThemeFamily.emocion,
      surface: const Color(0xFFCC308B),
    ),
  ];

  /// The neutral editorial surface: paper background, ink text, no tint —
  /// what an unrecognised slug falls back to, so [resolve] never throws.
  static const FluiThemeColor fallback = FluiThemeColor(
    slug: '_fallback',
    family: null,
    surface: FluiColors.paper,
    on: FluiColors.ink,
    tint: FluiColors.paper,
  );

  static final Map<String, FluiThemeColor> _bySlug = {
    for (final color in all) color.slug: color,
  };

  /// The theme colour for [slug], or [fallback] when [slug] isn't one of
  /// the 28 in `content/themes.yml`. Never throws.
  static FluiThemeColor resolve(String slug) => _bySlug[slug] ?? fallback;
}
