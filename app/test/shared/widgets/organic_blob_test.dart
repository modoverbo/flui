import 'dart:math' as math;

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/shared/widgets/organic_blob.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('OrganicBlobShape.radiusAt (pure shape math)', () {
    test('with wobble 0, the radius profile is calm: small variance', () {
      const base = 80.0;
      final radii = <double>[
        for (var i = 0; i < 360; i += 10)
          OrganicBlobShape.radiusAt(
            i * math.pi / 180,
            baseRadius: base,
            wobble: 0,
            seed: 1.23,
          ),
      ];
      final spread = radii.reduce(math.max) - radii.reduce(math.min);
      // Still two-lobed (never a perfect circle, per the logo silhouette)
      // but the swing stays small at rest.
      expect(spread, greaterThan(0));
      expect(spread, lessThan(base * 0.12));
    });

    test('higher wobble deforms the shape more than lower wobble', () {
      const base = 80.0;
      double spreadFor(double wobble) {
        final radii = <double>[
          for (var i = 0; i < 360; i += 10)
            OrganicBlobShape.radiusAt(
              i * math.pi / 180,
              baseRadius: base,
              wobble: wobble,
              seed: 0.5,
            ),
        ];
        return radii.reduce(math.max) - radii.reduce(math.min);
      }

      expect(spreadFor(1), greaterThan(spreadFor(0.2)));
    });

    test('different seeds produce different shapes at the same angle', () {
      final a = OrganicBlobShape.radiusAt(
        0.7,
        baseRadius: 80,
        wobble: 0.8,
        seed: 0.1,
      );
      final b = OrganicBlobShape.radiusAt(
        0.7,
        baseRadius: 80,
        wobble: 0.8,
        seed: 4.2,
      );
      expect(a, isNot(closeTo(b, 0.001)));
    });

    test('radius is always positive and finite for any input', () {
      for (final wobble in [-5.0, 0.0, 0.5, 1.0, 3.0]) {
        for (final seed in [-10.0, 0.0, 10.0, double.nan]) {
          final r = OrganicBlobShape.radiusAt(
            1,
            baseRadius: 80,
            wobble: wobble,
            seed: seed,
          );
          expect(r.isFinite, isTrue);
          expect(r, greaterThan(0));
        }
      }
    });
  });

  group('OrganicBlobPainter.shouldRepaint', () {
    OrganicBlobPainter painter({
      double wobble = 0,
      double seed = 0,
      double scale = 1,
      List<Color> colors = const [FluiColors.lavender, FluiColors.electricBlue],
    }) => OrganicBlobPainter(
      wobble: wobble,
      seed: seed,
      scale: scale,
      colors: colors,
    );

    test('repaints when wobble changes', () {
      expect(painter().shouldRepaint(painter(wobble: 0.5)), isTrue);
    });

    test('repaints when seed changes', () {
      expect(painter().shouldRepaint(painter(seed: 0.5)), isTrue);
    });

    test('repaints when scale changes', () {
      expect(painter().shouldRepaint(painter(scale: 1.1)), isTrue);
    });

    test('repaints when colors change', () {
      expect(
        painter().shouldRepaint(
          painter(colors: const [FluiColors.acidLime, FluiColors.aqua]),
        ),
        isTrue,
      );
    });

    test('does not repaint when nothing driving the paint changed', () {
      expect(painter().shouldRepaint(painter()), isFalse);
    });
  });

  group('OrganicBlob widget', () {
    testWidgets('paints at the requested size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OrganicBlob(size: 120, wobble: 0.4)),
        ),
      );
      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).last,
      );
      expect(customPaint.size, const Size.square(120));
    });

    testWidgets('is wrapped in a RepaintBoundary for isolation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OrganicBlob(size: 120, wobble: 0.4)),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(OrganicBlob),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('renders without error across a range of wobble values', (
      tester,
    ) async {
      for (final wobble in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: OrganicBlob(size: 100, wobble: wobble)),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
