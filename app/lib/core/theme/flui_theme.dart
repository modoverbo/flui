import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
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
      outline: FluiColors.hairlineOnCream,
      outlineVariant: FluiColors.hairlineOnCream,
    );
    return _build(scheme, onDark: false);
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
      // Never gray on green: 2.49:1.
      onSurfaceVariant: FluiColors.creamMuted,
      surfaceContainer: FluiColors.greenDeep,
      outline: FluiColors.hairlineOnGreen,
      outlineVariant: FluiColors.hairlineOnGreen,
    );
    return _build(scheme, onDark: true);
  }

  static ThemeData _build(ColorScheme scheme, {required bool onDark}) {
    // Material widgets get the compact scale; screens resolve the responsive
    // one through `context.type`.
    const scale = FluiTypeScale.compact;
    final textTheme = scale.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    final hairline = onDark
        ? FluiColors.hairlineOnGreen
        : FluiColors.hairlineOnCream;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: FluiFonts.text,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      // Flat by design: the only shadow is FluiSurfaces.ctaDockShadow.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: onDark ? FluiColors.greenDeep : FluiColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FluiSpacing.md,
          vertical: FluiSpacing.md,
        ),
        border: const OutlineInputBorder(borderRadius: FluiRadii.chipAll),
        enabledBorder: const OutlineInputBorder(
          borderRadius: FluiRadii.chipAll,
          borderSide: BorderSide(color: FluiColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FluiRadii.chipAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: FluiRadii.chipAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: FluiRadii.chipAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: scale.label.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: scale.label.copyWith(color: scheme.primary),
        hintStyle: scale.body.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: scale.body.copyWith(color: scheme.error, fontSize: 14),
        errorMaxLines: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: onDark ? FluiColors.greenDeep : FluiColors.surface,
        indicatorColor: Colors.transparent,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          scale.label.copyWith(color: scheme.onSurface),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: onDark ? FluiColors.greenDeep : FluiColors.surface,
        indicatorColor: Colors.transparent,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 22),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: scale.label.copyWith(color: scheme.primary),
        unselectedLabelTextStyle: scale.label.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FluiColors.charcoal,
        contentTextStyle: scale.body.copyWith(color: FluiColors.cream),
        shape: const RoundedRectangleBorder(borderRadius: FluiRadii.cardAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: onDark
            ? FluiColors.greenSecondary
            : FluiColors.greenTint,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: FluiRadii.chipAll),
        side: BorderSide(color: scheme.onSurfaceVariant, width: 1.5),
      ),
    );
  }
}
