import 'dart:io';

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/shared/widgets/flui_logo.dart';
import 'package:flui/shared/widgets/flui_symbol.dart';
import 'package:flui/shared/widgets/loading_wave.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('FluiSymbolGeometry', () {
    for (final (asset, color) in [
      ('assets/brand/flui_symbol.svg', '#FFD60A'),
      ('assets/brand/flui_symbol_green.svg', '#0B3D34'),
    ]) {
      test('$asset uses the same waves as the painter', () {
        final svg = File(asset).readAsStringSync();

        for (final wave in FluiSymbolGeometry.waves) {
          expect(svg, contains('d="${FluiSymbolGeometry.svgPathData(wave)}"'));
        }
        expect(svg, contains('stroke="$color"'));
        expect(
          svg,
          contains('stroke-width="${FluiSymbolGeometry.strokeWidth.toInt()}"'),
        );
        expect(svg, contains('Tabler Icons'));
      });
    }

    test('path data uses compact SVG numbers', () {
      expect(
        FluiSymbolGeometry.svgPathData(FluiSymbolGeometry.waves.first),
        'M6 14c5.33 -4.4 10.67 -4.4 16 0s10.67 4.4 16 0',
      );
    });
  });

  testWidgets('FluiSymbol renders the tone asset with a label', (tester) async {
    await tester.pumpFlui(
      const FluiSymbol(
        tone: FluiSymbolTone.yellow,
        size: 64,
        semanticLabel: 'flui',
      ),
    );

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.width, 64);
    expect(picture.semanticsLabel, 'flui');
    expect(find.bySemanticsLabel('flui'), findsOneWidget);
  });

  testWidgets('FluiLogo shows the lowercase wordmark', (tester) async {
    await tester.pumpFlui(const FluiLogo(onDark: true));

    final wordmark = tester.widget<Text>(find.text('flui'));
    expect(wordmark.style?.color, FluiColors.cream);
    expect(find.byType(FluiSymbol), findsOneWidget);
  });

  testWidgets('FluiLogo stacked variant places the symbol above', (
    tester,
  ) async {
    await tester.pumpFlui(const FluiLogo(axis: Axis.vertical));

    final symbol = tester.getCenter(find.byType(FluiSymbol));
    final text = tester.getCenter(find.text('flui'));
    expect(symbol.dy, lessThan(text.dy));
  });

  testWidgets('LoadingWave animates and exposes a label', (tester) async {
    await tester.pumpFlui(
      const LoadingWave(semanticLabel: 'Cargando'),
      disableAnimations: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('LoadingWave stays still when animations are disabled', (
    tester,
  ) async {
    await tester.pumpFlui(const LoadingWave(semanticLabel: 'Cargando'));

    expect(tester.hasRunningAnimations, isFalse);
  });
}
