import 'package:flui/core/theme/contrast.dart';
import 'package:flui/core/theme/flui_color_rules.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_layout.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/core/theme/flui_surfaces.dart';
import 'package:flui/core/theme/flui_type_scale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('FluiSpacing', () {
    test('is the documented scale, in order, with no duplicates', () {
      expect(FluiSpacing.scale, [4, 8, 12, 16, 20, 24, 32, 40, 56, 80, 120]);
      expect(FluiSpacing.scale.toSet().length, FluiSpacing.scale.length);
      for (var i = 1; i < FluiSpacing.scale.length; i++) {
        expect(FluiSpacing.scale[i], greaterThan(FluiSpacing.scale[i - 1]));
      }
    });

    test('block and section gaps come from the scale', () {
      for (final value in [
        FluiSpacing.blockGapCompact,
        FluiSpacing.blockGapWide,
        FluiSpacing.sectionGapCompact,
        FluiSpacing.sectionGapWide,
        FluiSpacing.gutterCompact,
        FluiSpacing.gutterWide,
      ]) {
        expect(FluiSpacing.scale, contains(value));
      }
      expect(FluiSpacing.blockGapCompact, 32);
      expect(FluiSpacing.blockGapWide, 40);
      expect(FluiSpacing.sectionGapCompact, 56);
      expect(FluiSpacing.sectionGapWide, 80);
    });

    test('there is one content max-width policy', () {
      expect(FluiSpacing.contentMaxWidth, 720);
      expect(FluiSpacing.pageMaxWidth, 1120);
      expect(FluiSpacing.contentMaxWidth, lessThan(FluiSpacing.pageMaxWidth));
    });

    test('touch targets are at least 44 px', () {
      expect(FluiSpacing.minTapTarget, greaterThanOrEqualTo(44));
    });
  });

  group('FluiRadii', () {
    test('one radius per role', () {
      expect(FluiRadii.chip, 8);
      expect(FluiRadii.cta, 14);
      expect(FluiRadii.card, 16);
      expect(FluiRadii.plate, 28);
      expect(FluiRadii.pillRadius, 999);
    });

    test('the primary call to action is a rectangle, never a pill', () {
      expect(FluiRadii.cta, lessThan(FluiRadii.card));
      expect(FluiRadii.ctaAll, isNot(FluiRadii.pill));
    });
  });

  group('FluiLayout', () {
    test('switches form factor at the wide breakpoint', () {
      expect(FluiLayout.forWidth(390).formFactor, FluiFormFactor.compact);
      expect(
        FluiLayout.forWidth(FluiBreakpoints.wide - 1).formFactor,
        FluiFormFactor.compact,
      );
      expect(
        FluiLayout.forWidth(FluiBreakpoints.wide).formFactor,
        FluiFormFactor.wide,
      );
      expect(FluiLayout.forWidth(1440).isWide, isTrue);
    });

    test('resolves the type scale, gaps and gutters per form factor', () {
      const compact = FluiLayout(FluiFormFactor.compact);
      const wide = FluiLayout(FluiFormFactor.wide);

      expect(compact.type, FluiTypeScale.compact);
      expect(wide.type, FluiTypeScale.wide);
      expect(compact.blockGap, 32);
      expect(wide.blockGap, 40);
      expect(compact.sectionGap, 56);
      expect(wide.sectionGap, 80);
      expect(compact.gutter, 20);
      expect(wide.gutter, 40);
    });

    test('the web grid is 12 columns split 7 / 5', () {
      expect(
        FluiLayout.heroContentColumns + FluiLayout.heroSupportColumns,
        FluiLayout.columns,
      );
      expect(FluiLayout.heroContentColumns, 7);
    });

    testWidgets('reads the width from MediaQuery', (tester) async {
      late FluiLayout compact;
      late FluiLayout wide;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Builder(
            builder: (context) {
              compact = context.layout;
              return MediaQuery(
                data: const MediaQueryData(size: Size(1440, 900)),
                child: Builder(
                  builder: (context) {
                    wide = context.layout;
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(compact.isCompact, isTrue);
      expect(wide.isWide, isTrue);
      expect(wide.type, FluiTypeScale.wide);
    });
  });

  group('FluiMotion', () {
    test('has the four documented durations, in order', () {
      expect(FluiMotion.durations.map((d) => d.inMilliseconds), [
        120,
        200,
        320,
        900,
      ]);
    });

    test('leaving is 0.8x of arriving', () {
      expect(FluiMotion.exitOf(FluiMotion.standard).inMilliseconds, 256);
      expect(FluiMotion.exitOf(FluiMotion.quick).inMilliseconds, 160);
    });

    test('named motions match the design', () {
      expect(FluiMotion.wordReveal.inMilliseconds, 320);
      expect(FluiMotion.wordRevealStagger.inMilliseconds, 40);
      expect(FluiMotion.wordRevealScale, 1.02);
      expect(FluiMotion.underlineDraw.inMilliseconds, 220);
      expect(FluiMotion.shake.inMilliseconds, 260);
      expect(FluiMotion.shakeCycles, 3);
      expect(FluiMotion.shakeOffset, 6);
      expect(FluiMotion.progress.inMilliseconds, 400);
      expect(FluiMotion.sectionEntrance.inMilliseconds, 200);
      expect(FluiMotion.sectionStagger.inMilliseconds, 60);
      expect(FluiMotion.sectionRise, 12);
    });

    test('the streak celebrates only on milestones', () {
      for (final streak in [3, 7, 14, 30]) {
        expect(FluiMotion.isMilestone(streak), isTrue, reason: '$streak');
      }
      for (final streak in [0, 1, 2, 4, 6, 8, 13, 15, 29, 31, 100]) {
        expect(FluiMotion.isMilestone(streak), isFalse, reason: '$streak');
      }
    });

    testWidgets('resolve returns zero when animations are disabled', (
      tester,
    ) async {
      late Duration on;
      late Duration off;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              on = FluiMotion.resolve(context, FluiMotion.standard);
              return MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Builder(
                  builder: (context) {
                    off = FluiMotion.resolve(context, FluiMotion.standard);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(on, FluiMotion.standard);
      expect(off, Duration.zero);
    });
  });

  group('FluiSurfaces', () {
    test('hairlines are the documented translucent values', () {
      expect(FluiSurfaces.hairlineOnCream.color, const Color(0x140B3D34));
      expect(FluiSurfaces.hairlineOnGreen.color, const Color(0x1AF8F8F6));
      expect(FluiSurfaces.hairlineOnCream.width, 1);
    });

    test('there is exactly one shadow, for the sticky CTA dock', () {
      expect(FluiSurfaces.ctaDockShadow, hasLength(1));
      expect(FluiSurfaces.ctaDockShadow.single.offset.dy, lessThan(0));
    });

    test('hairline picks the tone of its surface', () {
      expect(FluiSurfaces.hairline(onDark: true), FluiSurfaces.hairlineOnGreen);
      expect(
        FluiSurfaces.hairline(onDark: false),
        FluiSurfaces.hairlineOnCream,
      );
    });
  });

  group('FluiColorRules', () {
    for (final pair in FluiColorRules.readable) {
      test('${pair.name} meets WCAG AA for text', () {
        expect(
          contrastRatio(pair.foreground, pair.background),
          greaterThanOrEqualTo(FluiColorRules.aaText),
        );
      });
    }

    for (final pair in FluiColorRules.borders) {
      test('${pair.name} meets the 3:1 non-text minimum', () {
        expect(
          contrastRatio(pair.foreground, pair.background),
          greaterThanOrEqualTo(FluiColorRules.aaLargeText),
        );
      });
    }

    for (final pair in FluiColorRules.forbidden) {
      test('${pair.name} is unreadable and therefore banned', () {
        expect(
          contrastRatio(pair.foreground, pair.background),
          lessThan(FluiColorRules.aaLargeText),
        );
      });
    }

    test('the documented ratios still hold', () {
      expect(
        contrastRatio(FluiColors.yellowElectric, FluiColors.greenDeep),
        closeTo(8.59, 0.01),
      );
      expect(
        contrastRatio(FluiColors.cream, FluiColors.greenDeep),
        closeTo(11.41, 0.01),
      );
      expect(
        contrastRatio(FluiColors.charcoal, FluiColors.yellowElectric),
        closeTo(13.58, 0.01),
      );
      expect(
        contrastRatio(FluiColors.gray, FluiColors.greenDeep),
        closeTo(2.49, 0.01),
      );
      expect(
        contrastRatio(FluiColors.yellowElectric, FluiColors.cream),
        closeTo(1.33, 0.01),
      );
    });

    test('creamMuted replaces gray on green and is readable', () {
      expect(FluiColorRules.onGreenSecondaryText, FluiColors.creamMuted);
      expect(
        contrastRatio(FluiColors.creamMuted, FluiColors.greenDeep),
        greaterThanOrEqualTo(FluiColorRules.aaText),
      );
    });

    test('yellow surfaces carry charcoal, never green', () {
      expect(FluiColorRules.onYellow, FluiColors.charcoal);
      expect(FluiColorRules.onYellow, isNot(FluiColors.greenDeep));
    });

    test('yellow has exactly four roles', () {
      expect(YellowRole.values, hasLength(4));
    });
  });
}
