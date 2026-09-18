import 'package:flui/core/theme/contrast.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('FluiColors', () {
    test('brand palette matches docs/brand.md', () {
      expect(FluiColors.cream, const Color(0xFFFFF9F2));
      expect(FluiColors.greenDeep, const Color(0xFF0B3D34));
      expect(FluiColors.greenSecondary, const Color(0xFF165A4B));
      expect(FluiColors.charcoal, const Color(0xFF151426));
      expect(FluiColors.yellowElectric, const Color(0xFFFFD60A));
      expect(FluiColors.gray, const Color(0xFF687280));
      expect(FluiColors.creamMuted, const Color(0xFFB9C4BF));
    });

    test('expressive palette assigns a distinct color to every skill', () {
      expect(FluiColors.ink, const Color(0xFF151426));
      expect(FluiColors.paper, const Color(0xFFFFF9F2));
      expect(FluiColors.skill(SkillColor.voice), FluiColors.electricBlue);
      expect(FluiColors.skill(SkillColor.fluency), FluiColors.aqua);
      expect(FluiColors.skill(SkillColor.vocabulary), FluiColors.softPink);
      expect(FluiColors.skill(SkillColor.progress), FluiColors.acidLime);
    });
  });

  group('contrastRatio', () {
    test('black on white is 21:1 and symmetric', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);

      expect(contrastRatio(black, white), closeTo(21, 0.01));
      expect(contrastRatio(white, black), closeTo(21, 0.01));
    });
  });

  group('FluiTheme.light', () {
    final theme = FluiTheme.light();

    test('maps brand colors into the color scheme', () {
      final scheme = theme.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, FluiColors.electricBlue);
      expect(scheme.onPrimary, FluiColors.cream);
      expect(scheme.secondary, FluiColors.aqua);
      expect(scheme.tertiary, FluiColors.acidLime);
      expect(scheme.onTertiary, FluiColors.charcoal);
      expect(scheme.surface, FluiColors.cream);
      expect(scheme.onSurface, FluiColors.charcoal);
      expect(scheme.onSurfaceVariant, FluiColors.gray);
      expect(theme.scaffoldBackgroundColor, FluiColors.cream);
    });

    test('text theme is built from the type scale', () {
      final text = theme.textTheme;
      expect(
        text.displayLarge?.fontSize,
        FluiTypeScale.compact.wordHero.fontSize,
      );
      expect(text.displayLarge?.fontFamily, FluiFonts.display);
      expect(text.bodyMedium?.fontFamily, FluiFonts.text);
      expect(text.bodyMedium?.fontSize, FluiTypeScale.compact.body.fontSize);
      expect(text.bodyMedium?.color, FluiColors.charcoal);
      expect(
        text.labelMedium?.letterSpacing,
        FluiTypeScale.compact.label.letterSpacing,
      );
    });

    test('surfaces are flat: no widget theme carries an elevation', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.navigationBarTheme.elevation, 0);
    });

    test('hairlines replace the old solid outline', () {
      expect(theme.colorScheme.outline, FluiColors.hairlineOnCream);
      expect(theme.dividerTheme.color, FluiColors.hairlineOnCream);
    });

    test('progress surface is a dark variant that never uses gray text', () {
      final dark = FluiTheme.progressSurface();
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.colorScheme.surface, FluiColors.progressSurface);
      expect(dark.colorScheme.onSurface, FluiColors.cream);
      expect(dark.colorScheme.onSurfaceVariant, FluiColors.creamMuted);
      expect(dark.colorScheme.onSurfaceVariant, isNot(FluiColors.gray));
      expect(dark.colorScheme.outline, FluiColors.hairlineOnGreen);
    });
  });
}
