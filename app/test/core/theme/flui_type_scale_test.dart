import 'dart:io';

import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('FluiTypeScale roles', () {
    void expectRole(
      TextStyle style, {
      required String family,
      required FontWeight weight,
      required double size,
      required double lineHeight,
      required double tracking,
    }) {
      expect(style.fontFamily, family);
      expect(style.fontWeight, weight);
      expect(style.fontSize, size);
      expect(style.height! * style.fontSize!, closeTo(lineHeight, 0.001));
      expect(style.letterSpacing! / style.fontSize!, closeTo(tracking, 0.0005));
    }

    test('compact display roles match the mobile scale', () {
      expectRole(
        FluiTypeScale.compact.wordHero,
        family: FluiFonts.display,
        weight: FontWeight.w800,
        size: 72,
        lineHeight: 68,
        tracking: -0.03,
      );
      expectRole(
        FluiTypeScale.compact.displayL,
        family: FluiFonts.display,
        weight: FontWeight.w700,
        size: 44,
        lineHeight: 46,
        tracking: -0.02,
      );
      expectRole(
        FluiTypeScale.compact.titleL,
        family: FluiFonts.display,
        weight: FontWeight.w700,
        size: 28,
        lineHeight: 32,
        tracking: -0.015,
      );
      expectRole(
        FluiTypeScale.compact.titleM,
        family: FluiFonts.display,
        weight: FontWeight.w600,
        size: 22,
        lineHeight: 28,
        tracking: -0.01,
      );
      expectRole(
        FluiTypeScale.compact.numeralHero,
        family: FluiFonts.display,
        weight: FontWeight.w800,
        size: 96,
        lineHeight: 88,
        tracking: -0.03,
      );
    });

    test('wide display roles match the web scale', () {
      expectRole(
        FluiTypeScale.wide.wordHero,
        family: FluiFonts.display,
        weight: FontWeight.w800,
        size: 112,
        lineHeight: 104,
        tracking: -0.03,
      );
      expectRole(
        FluiTypeScale.wide.displayL,
        family: FluiFonts.display,
        weight: FontWeight.w700,
        size: 64,
        lineHeight: 62,
        tracking: -0.02,
      );
      expectRole(
        FluiTypeScale.wide.titleL,
        family: FluiFonts.display,
        weight: FontWeight.w700,
        size: 34,
        lineHeight: 38,
        tracking: -0.015,
      );
      expectRole(
        FluiTypeScale.wide.titleM,
        family: FluiFonts.display,
        weight: FontWeight.w600,
        size: 24,
        lineHeight: 30,
        tracking: -0.01,
      );
      expectRole(
        FluiTypeScale.wide.numeralHero,
        family: FluiFonts.display,
        weight: FontWeight.w800,
        size: 144,
        lineHeight: 128,
        tracking: -0.03,
      );
    });

    test('text roles are Inter and do not change with the viewport', () {
      for (final scale in [FluiTypeScale.compact, FluiTypeScale.wide]) {
        expect(scale.bodyL.fontFamily, FluiFonts.text);
        expect(scale.bodyL.fontSize, 18);
        expect(scale.bodyL.height! * 18, closeTo(28, 0.001));
        expect(scale.body.fontSize, 16);
        expect(scale.body.height! * 16, closeTo(26, 0.001));
        expect(scale.body.fontWeight, FontWeight.w400);
        expect(scale.label.fontSize, 13);
        expect(scale.label.height! * 13, closeTo(16, 0.001));
        expect(scale.label.fontWeight, FontWeight.w600);
        expect(scale.label.letterSpacing! / 13, closeTo(0.06, 0.0005));
        expect(scale.phonetic.fontSize, 15);
        expect(scale.phonetic.height! * 15, closeTo(20, 0.001));
      }
    });

    test('phonetic uses tabular figures so IPA columns line up', () {
      expect(
        FluiTypeScale.compact.phonetic.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('numeralHero uses tabular figures so counters do not jitter', () {
      for (final scale in [FluiTypeScale.compact, FluiTypeScale.wide]) {
        expect(
          scale.numeralHero.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('labels are rendered uppercase', () {
      expect(FluiTypeScale.labelText('en contexto'), 'EN CONTEXTO');
    });
  });

  group('type scale rules', () {
    test('display leading is 1.05 or tighter', () {
      for (final scale in [FluiTypeScale.compact, FluiTypeScale.wide]) {
        for (final role in FluiTypeScale.displayRoles) {
          expect(
            scale.styleOf(role).height,
            lessThanOrEqualTo(1.05),
            reason: '$role leading',
          );
        }
      }
    });

    test('body leading is 1.55 or looser', () {
      for (final scale in [FluiTypeScale.compact, FluiTypeScale.wide]) {
        for (final role in FluiTypeScale.bodyRoles) {
          expect(
            scale.styleOf(role).height,
            greaterThanOrEqualTo(1.55),
            reason: '$role leading',
          );
        }
      }
    });

    test('every role resolves to a style with size, height and family', () {
      for (final scale in [FluiTypeScale.compact, FluiTypeScale.wide]) {
        for (final role in FluiTypeRole.values) {
          final style = scale.styleOf(role);
          expect(style.fontSize, isNotNull, reason: '$role');
          expect(style.height, isNotNull, reason: '$role');
          expect(style.fontFamily, isNotNull, reason: '$role');
        }
      }
    });

    test('wide never renders a role smaller than compact', () {
      for (final role in FluiTypeRole.values) {
        expect(
          FluiTypeScale.wide.styleOf(role).fontSize,
          greaterThanOrEqualTo(FluiTypeScale.compact.styleOf(role).fontSize!),
          reason: '$role',
        );
      }
    });

    test('every weight the scale uses is bundled in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml')
          .readAsStringSync()
          .replaceAll(RegExp(r'\r?\n'), '\n');
      bool bundled(String family, int weight) => RegExp(
        'family: $family\n'
        r'(?:(?!\s*- family:).*\n)*?'
        '.*weight: $weight\n',
      ).hasMatch(pubspec);

      for (final scale in [FluiTypeScale.compact, FluiTypeScale.wide]) {
        for (final role in FluiTypeRole.values) {
          final style = scale.styleOf(role);
          expect(
            bundled(style.fontFamily!, style.fontWeight!.value),
            isTrue,
            reason: '$role needs ${style.fontFamily} ${style.fontWeight}',
          );
        }
      }
    });
  });
}
