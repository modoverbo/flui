import 'dart:io';

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/shared/widgets/flui_glyph.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('the glyph family', () {
    test('has ten glyphs, one asset each, all distinct', () {
      expect(FluiGlyph.values, hasLength(10));
      expect(FluiGlyph.values.map((g) => g.assetName).toSet(), hasLength(10));
      for (final glyph in FluiGlyph.values) {
        expect(File(glyph.asset).existsSync(), isTrue, reason: glyph.asset);
      }
    });

    test('covers the ten concepts of the brief', () {
      expect(FluiGlyph.values.map((g) => g.assetName), [
        'onda',
        'palabra-del-dia',
        'reemplaza',
        'racha',
        'en-contexto',
        'matiz-registro',
        'microfono',
        'meta',
        'logro',
        'repaso',
      ]);
    });

    test('every glyph shares grid, stroke and terminals', () {
      for (final glyph in FluiGlyph.values) {
        final svg = File(glyph.asset).readAsStringSync();
        expect(svg, contains('viewBox="0 0 24 24"'), reason: glyph.assetName);
        expect(
          svg,
          contains('stroke-width="${FluiGlyphGeometry.strokeWidth.toInt()}"'),
          reason: glyph.assetName,
        );
        expect(
          svg,
          contains('stroke-linecap="${FluiGlyphGeometry.lineCap}"'),
          reason: glyph.assetName,
        );
        expect(
          svg,
          contains('stroke-linejoin="${FluiGlyphGeometry.lineJoin}"'),
          reason: glyph.assetName,
        );
        // Recolored at render time, so one asset serves cream and charcoal.
        expect(svg, contains('currentColor'), reason: glyph.assetName);
        expect(svg, isNot(contains('#')), reason: glyph.assetName);
        expect(svg, contains('<title>'), reason: glyph.assetName);
      }
    });

    test('stays inside the 24 grid so optical size is shared', () {
      final number = RegExp(r'-?\d+(?:\.\d+)?');
      for (final glyph in FluiGlyph.values) {
        final body = File(glyph.asset)
            .readAsStringSync()
            .split('\n')
            .where((line) => line.contains('<path') || line.contains('<circle'))
            .join(' ');
        for (final match in number.allMatches(body)) {
          final value = double.parse(match[0]!);
          expect(
            value,
            inInclusiveRange(-24, 24),
            reason: '${glyph.assetName}: $value',
          );
        }
      }
    });

    test('the directory holds no stray assets', () {
      final files = Directory(FluiGlyphGeometry.assetDirectory)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(files.length, FluiGlyph.values.length);
    });

    test('pubspec.yaml ships the glyph directory', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('${FluiGlyphGeometry.assetDirectory}/'));
    });
  });

  group('FluiIconSize', () {
    test('is exactly the three documented sizes', () {
      expect(FluiIconSize.values.map((s) => s.value), [22, 20, 18]);
    });
  });

  group('FluiGlyphIcon', () {
    testWidgets('renders at its size and takes the icon theme color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const IconTheme(
          data: IconThemeData(color: FluiColors.cream),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FluiGlyphIcon(FluiGlyph.streak, size: FluiIconSize.tab),
          ),
        ),
      );

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(picture.width, 22);
      expect(picture.height, 22);
      expect(
        picture.colorFilter,
        const ColorFilter.mode(FluiColors.cream, BlendMode.srcIn),
      );
    });

    testWidgets('is hidden from screen readers unless labelled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              FluiGlyphIcon(FluiGlyph.goal),
              FluiGlyphIcon(FluiGlyph.review, semanticLabel: 'Repaso'),
            ],
          ),
        ),
      );

      final pictures = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .toList();
      expect(pictures.first.semanticsLabel, isNull);
      expect(pictures.last.semanticsLabel, 'Repaso');
    });
  });
}
