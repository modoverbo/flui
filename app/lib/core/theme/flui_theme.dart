import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:material_ui/material_ui.dart';

abstract final class FluiTheme {
  /// The app theme: cream background, deep green actions, charcoal text.
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: FluiColors.greenDeep,
      onPrimary: FluiColors.cream,
      primaryContainer: FluiColors.greenTint,
      onPrimaryContainer: FluiColors.greenDeep,
      secondary: FluiColors.greenSecondary,
      onSecondary: FluiColors.cream,
      secondaryContainer: FluiColors.greenTint,
      onSecondaryContainer: FluiColors.greenDeep,
      tertiary: FluiColors.yellowElectric,
      onTertiary: FluiColors.charcoal,
      tertiaryContainer: FluiColors.yellowTint,
      onTertiaryContainer: FluiColors.charcoal,
      error: FluiColors.alert,
      onError: FluiColors.cream,
      surface: FluiColors.cream,
      onSurface: FluiColors.charcoal,
      onSurfaceVariant: FluiColors.gray,
      surfaceContainerLowest: FluiColors.surface,
      surfaceContainerLow: FluiColors.surface,
      surfaceContainer: FluiColors.surface,
      surfaceContainerHigh: FluiColors.surface,
      outline: FluiColors.outline,
      outlineVariant: FluiColors.outline,
    );
    return _build(scheme);
  }

  /// Dark surface for progress and stats areas.
  static ThemeData progressSurface() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: FluiColors.yellowElectric,
      onPrimary: FluiColors.charcoal,
      secondary: FluiColors.greenSecondary,
      onSecondary: FluiColors.cream,
      tertiary: FluiColors.yellowElectric,
      onTertiary: FluiColors.charcoal,
      error: FluiColors.yellowTint,
      onError: FluiColors.charcoal,
      surface: FluiColors.progressSurface,
      onSurface: FluiColors.cream,
      onSurfaceVariant: FluiColors.greenTint,
      surfaceContainer: FluiColors.greenDeep,
      outline: FluiColors.greenSecondary,
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final textTheme = FluiTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: FluiTypography.textFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FluiColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FluiSpacing.md,
          vertical: FluiSpacing.md,
        ),
        border: const OutlineInputBorder(borderRadius: FluiRadii.mdAll),
        enabledBorder: OutlineInputBorder(
          borderRadius: FluiRadii.mdAll,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FluiRadii.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: FluiRadii.mdAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: FluiRadii.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: FluiTypography.label.copyWith(color: FluiColors.gray),
        floatingLabelStyle: FluiTypography.label.copyWith(
          color: scheme.primary,
        ),
        hintStyle: FluiTypography.body.copyWith(color: FluiColors.gray),
        errorStyle: FluiTypography.caption.copyWith(color: scheme.error),
        errorMaxLines: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FluiColors.surface,
        indicatorColor: FluiColors.greenTint,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          FluiTypography.caption.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : FluiColors.gray,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: FluiColors.surface,
        indicatorColor: FluiColors.greenTint,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: const IconThemeData(color: FluiColors.gray),
        selectedLabelTextStyle: FluiTypography.label.copyWith(
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: FluiTypography.label.copyWith(
          color: FluiColors.gray,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FluiColors.charcoal,
        contentTextStyle: FluiTypography.body.copyWith(color: FluiColors.cream),
        shape: const RoundedRectangleBorder(borderRadius: FluiRadii.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: FluiColors.greenTint,
      ),
    );
  }
}
