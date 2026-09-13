/// Spacing scale (logical pixels). Prefer generous spacing.
abstract final class FluiSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Maximum width of reading and form content on wide screens.
  static const double contentMaxWidth = 560;

  /// Maximum width of app content next to the navigation rail.
  static const double appContentMaxWidth = 720;
}

/// Layout breakpoints (logical pixels).
abstract final class FluiBreakpoints {
  /// From this width the shell shows a navigation rail instead of a bar.
  static const double rail = 600;

  /// From this width the navigation rail shows labels next to icons.
  static const double extendedRail = 1024;
}
