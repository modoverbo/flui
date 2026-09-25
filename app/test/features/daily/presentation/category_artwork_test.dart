import 'package:flui/features/daily/presentation/category_artwork.dart';
import 'package:flui/features/themes/domain/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';

void main() {
  test('each family resolves to its approved production illustration', () {
    expect(ThemeFamily.values.map(CategoryArtwork.assetFor), [
      'assets/illustrations/categories/trabajo.png',
      'assets/illustrations/categories/social.png',
      'assets/illustrations/categories/publico.png',
      'assets/illustrations/categories/precision.png',
      'assets/illustrations/categories/emocion.png',
    ]);
  });

  test('category titles retain large-text contrast over card colors', () {
    for (final family in ThemeFamily.values) {
      final contrast =
          (CategoryArtwork.cardColorFor(family).computeLuminance() + 0.05) /
          (const Color(0xFF151426).computeLuminance() + 0.05);
      expect(contrast, greaterThanOrEqualTo(3), reason: family.name);
    }
  });

  testWidgets('all artwork loads without duplicating category labels', (
    tester,
  ) async {
    for (final family in ThemeFamily.values) {
      await tester.pumpFlui(
        SizedBox(
          width: 100,
          height: 100,
          child: CategoryArtwork(family: family),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: family.name);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.excludeFromSemantics, isTrue, reason: family.name);
    }
    expect(find.bySemanticsLabel('En el trabajo'), findsNothing);
  });
}
