import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:flui/shared/widgets/training_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Color? topBorderColor(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    return decoration.border?.top.color;
  }

  Color? fillColor(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    return (box.decoration as BoxDecoration).color;
  }

  testWidgets('resolves the theme colour of a known slug', (tester) async {
    final theme = FluiThemeColors.resolve('humor');
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingCard(themeSlug: 'humor', child: SizedBox()),
      ),
    );

    expect(topBorderColor(tester), theme.surface);
    expect(fillColor(tester), theme.tint);
  });

  testWidgets('falls back safely when the word has no theme', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TrainingCard(child: SizedBox())),
    );

    expect(topBorderColor(tester), FluiThemeColors.fallback.surface);
    expect(fillColor(tester), FluiThemeColors.fallback.tint);
  });

  testWidgets('falls back safely for an unknown slug, never throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingCard(themeSlug: 'not-a-real-theme', child: SizedBox()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(topBorderColor(tester), FluiThemeColors.fallback.surface);
  });

  testWidgets('only the front position paints the stack shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TrainingCard(child: SizedBox())),
    );
    final front = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((front.decoration as BoxDecoration).boxShadow, isNotEmpty);

    await tester.pumpWidget(
      const MaterialApp(home: TrainingCard(position: 1, child: SizedBox())),
    );
    final next = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((next.decoration as BoxDecoration).boxShadow, isEmpty);
  });
}
