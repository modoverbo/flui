import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/vocabulary/presentation/words_page.dart';
import 'package:flui/shared/widgets/bento_grid.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('every expressive bento tone resolves to the Flui palette', () {
    expect(bentoToneColor(BentoTone.ink), FluiColors.ink);
    expect(bentoToneColor(BentoTone.blue), FluiColors.electricBlue);
    expect(bentoToneColor(BentoTone.lime), FluiColors.acidLime);
    expect(bentoToneColor(BentoTone.coral), FluiColors.coral);
    expect(bentoToneColor(BentoTone.aqua), FluiColors.aqua);
    expect(bentoToneColor(BentoTone.pink), FluiColors.softPink);
    expect(bentoToneColor(BentoTone.lavender), FluiColors.lavender);
  });

  test('word cards rotate through expressive colors', () {
    expect(wordCardColor(0), FluiColors.softPink);
    expect(wordCardColor(1), FluiColors.aqua);
    expect(wordCardColor(2), FluiColors.acidLime);
    expect(wordCardColor(3), FluiColors.coral);
    expect(wordCardColor(4), FluiColors.lavender);
    expect(wordCardColor(5), FluiColors.softPink);
  });

  testWidgets('cards use the expressive ink outline and organic corners', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FluiCard(child: Text('idea'))),
      ),
    );

    final material = tester.widget<Material>(
      find
          .ancestor(of: find.text('idea'), matching: find.byType(Material))
          .first,
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color, FluiColors.ink);
    expect(shape.side.width, 1.5);
    expect(shape.borderRadius, expressiveCardRadius);
  });
}
