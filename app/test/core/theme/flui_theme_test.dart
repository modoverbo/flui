import 'dart:io';

import 'package:flui/core/theme/contrast.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_theme.dart';
import 'package:flui/core/theme/flui_typography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('FluiColors', () {
    test('brand palette matches docs/brand.md', () {
      expect(FluiColors.cream, const Color(0xFFF8F8F6));
      expect(FluiColors.greenDeep, const Color(0xFF0B3D34));
      expect(FluiColors.greenSecondary, const Color(0xFF165A4B));
      expect(FluiColors.charcoal, const Color(0xFF0F0F0F));
      expect(FluiColors.yellowElectric, const Color(0xFFFFD60A));
      expect(FluiColors.gray, const Color(0xFF687280));
    });

    const aaText = 4.5;
    final readablePairs = <String, (Color, Color)>{
      'charcoal on cream': (FluiColors.charcoal, FluiColors.cream),
      'charcoal on surface': (FluiColors.charcoal, FluiColors.surface),
      'cream on greenDeep': (FluiColors.cream, FluiColors.greenDeep),
      'cream on greenSecondary': (FluiColors.cream, FluiColors.greenSecondary),
      'charcoal on yellowElectric': (
        FluiColors.charcoal,
        FluiColors.yellowElectric,
      ),
      'yellowElectric on greenDeep': (
        FluiColors.yellowElectric,
        FluiColors.greenDeep,
      ),
      'gray on cream': (FluiColors.gray, FluiColors.cream),
      'greenDeep on greenTint': (FluiColors.greenDeep, FluiColors.greenTint),
      'charcoal on yellowTint': (FluiColors.charcoal, FluiColors.yellowTint),
      'alert on cream': (FluiColors.alert, FluiColors.cream),
      'cream on progressSurface': (
        FluiColors.cream,
        FluiColors.progressSurface,
      ),
    };

    for (final MapEntry(key: name, value: (fg, bg)) in readablePairs.entries) {
      test('$name meets WCAG AA for text', () {
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(aaText));
      });
    }

    test('yellow on cream is never readable (documented rule)', () {
      expect(
        contrastRatio(FluiColors.yellowElectric, FluiColors.cream),
        lessThan(3),
      );
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

  group('FluiTypography', () {
    void expectStyle(
      TextStyle style, {
      required String family,
      required FontWeight weight,
      required double size,
      required double lineHeight,
    }) {
      expect(style.fontFamily, family);
      expect(style.fontWeight, weight);
      expect(style.fontSize, size);
      expect(style.height! * style.fontSize!, closeTo(lineHeight, 0.001));
    }

    test('display styles use Plus Jakarta Sans', () {
      expectStyle(
        FluiTypography.featuredWord,
        family: FluiTypography.displayFamily,
        weight: FontWeight.w800,
        size: 40,
        lineHeight: 48,
      );
      expectStyle(
        FluiTypography.h1,
        family: FluiTypography.displayFamily,
        weight: FontWeight.w800,
        size: 28,
        lineHeight: 36,
      );
      expectStyle(
        FluiTypography.h2,
        family: FluiTypography.displayFamily,
        weight: FontWeight.w700,
        size: 22,
        lineHeight: 28,
      );
      expectStyle(
        FluiTypography.h3,
        family: FluiTypography.displayFamily,
        weight: FontWeight.w700,
        size: 18,
        lineHeight: 24,
      );
    });

    test('text styles use Inter', () {
      expectStyle(
        FluiTypography.body,
        family: FluiTypography.textFamily,
        weight: FontWeight.w400,
        size: 16,
        lineHeight: 24,
      );
      expectStyle(
        FluiTypography.bodyEmphasis,
        family: FluiTypography.textFamily,
        weight: FontWeight.w600,
        size: 16,
        lineHeight: 24,
      );
      expectStyle(
        FluiTypography.label,
        family: FluiTypography.textFamily,
        weight: FontWeight.w600,
        size: 14,
        lineHeight: 20,
      );
      expectStyle(
        FluiTypography.caption,
        family: FluiTypography.textFamily,
        weight: FontWeight.w400,
        size: 12,
        lineHeight: 16,
      );
    });

    test('family names match the fonts declared in pubspec.yaml', () {
      expect(FluiTypography.displayFamily, 'PlusJakartaSans');
      expect(FluiTypography.textFamily, 'Inter');
    });

    test('every weight used by the hierarchy is bundled', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final styles = [
        FluiTypography.featuredWord,
        FluiTypography.h1,
        FluiTypography.h2,
        FluiTypography.h3,
        FluiTypography.body,
        FluiTypography.bodyEmphasis,
        FluiTypography.label,
        FluiTypography.caption,
      ];
      // Matches a weight inside one `- family:` block only.
      bool bundled(String family, int weight) => RegExp(
        'family: $family\\n(?:(?!\\s*- family:).*\\n)*?.*weight: $weight\\n',
      ).hasMatch(pubspec);

      for (final style in styles) {
        final family = style.fontFamily!;
        final weight = style.fontWeight!.value;
        expect(bundled(family, weight), isTrue, reason: '$family $weight');
      }
      expect(bundled(FluiTypography.displayFamily, 400), isFalse);
    });
  });

  group('spacing and radii', () {
    test('spacing follows a 4 pt scale', () {
      final scale = [
        FluiSpacing.xxs,
        FluiSpacing.xs,
        FluiSpacing.sm,
        FluiSpacing.md,
        FluiSpacing.lg,
        FluiSpacing.xl,
        FluiSpacing.xxl,
      ];
      expect(scale, [4, 8, 12, 16, 24, 32, 48]);
    });

    test('radii are rounded and increasing', () {
      expect(FluiRadii.sm < FluiRadii.md, isTrue);
      expect(FluiRadii.md < FluiRadii.lg, isTrue);
      expect(FluiRadii.lg < FluiRadii.xl, isTrue);
    });
  });

  group('FluiTheme.light', () {
    final theme = FluiTheme.light();

    test('maps brand colors into the color scheme', () {
      final scheme = theme.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, FluiColors.greenDeep);
      expect(scheme.onPrimary, FluiColors.cream);
      expect(scheme.secondary, FluiColors.greenSecondary);
      expect(scheme.tertiary, FluiColors.yellowElectric);
      expect(scheme.onTertiary, FluiColors.charcoal);
      expect(scheme.surface, FluiColors.cream);
      expect(scheme.onSurface, FluiColors.charcoal);
      expect(scheme.onSurfaceVariant, FluiColors.gray);
      expect(theme.scaffoldBackgroundColor, FluiColors.cream);
    });

    test('text theme uses the brand hierarchy', () {
      final text = theme.textTheme;
      expect(text.headlineMedium?.fontSize, FluiTypography.h1.fontSize);
      expect(text.headlineMedium?.fontFamily, FluiTypography.displayFamily);
      expect(text.bodyLarge?.fontFamily, FluiTypography.textFamily);
      expect(text.labelLarge?.fontWeight, FontWeight.w600);
      expect(text.bodyLarge?.color, FluiColors.charcoal);
    });

    test('progress surface is a dark variant for stats', () {
      final dark = FluiTheme.progressSurface();
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.colorScheme.surface, FluiColors.progressSurface);
      expect(dark.colorScheme.onSurface, FluiColors.cream);
    });
  });
}
