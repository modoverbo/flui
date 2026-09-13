/// Spacing scale (logical pixels): 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 56 ·
/// 80 · 120. Nothing in the app may use a value outside it.
abstract final class FluiSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double ml = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double section = 56;
  static const double sectionWide = 80;
  static const double hero = 120;

  /// The whole scale, in order. Tests assert layouts only use these.
  static const List<double> scale = [
    xxs,
    xs,
    sm,
    md,
    ml,
    lg,
    xl,
    xxl,
    section,
    sectionWide,
    hero,
  ];

  /// Gap between blocks inside a section.
  static const double blockGapCompact = xl;
  static const double blockGapWide = xxl;

  /// Gap between sections of a page.
  static const double sectionGapCompact = section;
  static const double sectionGapWide = sectionWide;

  /// One content max-width policy, replacing the old 560 / 720 split:
  /// text columns are [contentMaxWidth] wide and page frames are
  /// [pageMaxWidth] wide (the 12-column grid of the web layouts).
  static const double contentMaxWidth = 720;
  static const double pageMaxWidth = 1120;

  /// Horizontal page gutters.
  static const double gutterCompact = ml;
  static const double gutterWide = xxl;

  /// Minimum interactive target (WCAG 2.2 target size, AAA).
  static const double minTapTarget = 44;
}

/// Layout breakpoints (logical pixels).
abstract final class FluiBreakpoints {
  /// From this width the shell shows a navigation rail instead of a bar.
  static const double rail = 600;

  /// From this width the type scale, gaps and layouts switch to "wide".
  static const double wide = 900;

  /// From this width the navigation rail shows labels next to icons.
  static const double extendedRail = 1024;
}
