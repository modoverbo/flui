import 'package:flui/core/theme/contrast.dart';
import 'package:flui/core/theme/flui_color_rules.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:flui/features/themes/data/fake/seed_themes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FluiThemeColors', () {
    test('has exactly the 28 theme colours of the taxonomy', () {
      expect(FluiThemeColors.all, hasLength(28));
      expect(
        FluiThemeColors.all.map((c) => c.slug).toSet().length,
        28,
        reason: 'no duplicate slugs',
      );
    });

    for (final color in FluiThemeColors.all) {
      test(
        '${color.slug}: on-colour meets AA text contrast on its surface',
        () {
          expect(
            contrastRatio(color.on, color.surface),
            greaterThanOrEqualTo(FluiColorRules.aaText),
          );
        },
      );

      test('${color.slug}: ink meets AA text contrast on its card tint', () {
        expect(
          contrastRatio(FluiColors.ink, color.tint),
          greaterThanOrEqualTo(FluiColorRules.aaText),
        );
      });

      test('${color.slug}: on-colour is uniformly paper', () {
        expect(color.on, FluiColors.paper);
      });
    }

    test('every theme in content/themes.yml resolves to its own colour', () {
      final taxonomy = [...seedThemes, ...unpublishedSeedThemes];
      expect(taxonomy, hasLength(28));

      for (final theme in taxonomy) {
        final color = FluiThemeColors.resolve(theme.slug);
        expect(color.slug, theme.slug, reason: 'resolved for ${theme.slug}');
        expect(color, isNot(FluiThemeColors.fallback));
      }
    });

    test('an unknown slug falls back to the neutral editorial surface', () {
      final color = FluiThemeColors.resolve('not-a-real-theme');

      expect(color, FluiThemeColors.fallback);
      expect(color.surface, FluiColors.paper);
      expect(color.on, FluiColors.ink);
    });

    test('resolve never throws, even for garbage input', () {
      expect(() => FluiThemeColors.resolve(''), returnsNormally);
      expect(() => FluiThemeColors.resolve('🎉'), returnsNormally);
      expect(() => FluiThemeColors.resolve('  reuniones  '), returnsNormally);
    });
  });

  group('FluiColorRules generated theme pairs', () {
    test('every theme colour is represented in readable', () {
      for (final color in FluiThemeColors.all) {
        expect(
          FluiColorRules.readable.map((p) => p.name),
          anyElement(contains(color.slug)),
          reason: '${color.slug} should contribute a readable pair',
        );
      }
    });
  });
}
