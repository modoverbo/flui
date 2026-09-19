import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_theme_colors.dart';
import 'package:flui/shared/widgets/training_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Two nested `DecoratedBox`es: the outer one paints the saturated `edge`
  // colour (visible as a thin frame all the way around once the inner one
  // insets), the inner one paints the subdued `tint` fill the actual
  // content sits on. See `TrainingCard.build`'s doc comment for why this
  // isn't a `BoxDecoration.border` instead.
  Color? edgeColor(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    return (box.decoration as BoxDecoration).color;
  }

  Color? fillColor(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).last);
    return (box.decoration as BoxDecoration).color;
  }

  testWidgets('resolves the theme colour of a known slug', (tester) async {
    final theme = FluiThemeColors.resolve('humor');
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingCard(themeSlug: 'humor', child: SizedBox()),
      ),
    );

    expect(edgeColor(tester), theme.surface);
    expect(fillColor(tester), theme.tint);
  });

  testWidgets('falls back safely when the word has no theme', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TrainingCard(child: SizedBox())),
    );

    expect(edgeColor(tester), FluiThemeColors.fallback.surface);
    expect(fillColor(tester), FluiThemeColors.fallback.tint);
  });

  testWidgets(
    'a themeless back card still gets a visible neutral edge (the front '
    'card is allowed to blend into the page when a word has no theme, but '
    'a back card is only ever a thin peeking edge — it must never '
    'disappear entirely just because the word behind it has no theme)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TrainingCard(position: 1, child: SizedBox())),
      );

      expect(edgeColor(tester), isNot(FluiThemeColors.fallback.surface));
      expect(edgeColor(tester), FluiColors.gray);
    },
  );

  testWidgets('falls back safely for an unknown slug, never throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingCard(themeSlug: 'not-a-real-theme', child: SizedBox()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(edgeColor(tester), FluiThemeColors.fallback.surface);
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

  testWidgets(
    'every card gets a saturated edge all the way around in the theme '
    'colour, not just a top accent (the bottom edge is the only part of a '
    'back card that ever peeks out from beneath the front card, so it '
    'needs the same strong colour cue as the rest — the subdued tint fill '
    'alone reads as almost the same colour as the page background at just '
    'a few pixels of peek)',
    (tester) async {
      final theme = FluiThemeColors.resolve('humor');
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainingCard(
            themeSlug: 'humor',
            position: 1,
            child: SizedBox(),
          ),
        ),
      );

      // The outer box (the edge colour) must be strictly larger than the
      // inner one (the tint fill) on every side — proof the edge is
      // visible all around, not just at the top.
      final outerSize = tester.getSize(find.byType(DecoratedBox).first);
      final innerSize = tester.getSize(find.byType(DecoratedBox).last);
      expect(outerSize.width, greaterThan(innerSize.width));
      expect(outerSize.height, greaterThan(innerSize.height));

      expect(edgeColor(tester), theme.surface);
      expect(fillColor(tester), theme.tint);
    },
  );

  testWidgets('content taller than the card scrolls internally instead of '
      'overflowing (the card itself never grows)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            height: 200,
            width: 300,
            child: TrainingCard(
              child: Column(
                children: List.generate(
                  20,
                  (i) => const SizedBox(height: 40, child: Text('line')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // No RenderFlex overflow exception, and the card's own box stays at
    // the size its ancestor gave it.
    expect(tester.takeException(), isNull);
    final cardSize = tester.getSize(find.byType(TrainingCard));
    expect(cardSize.height, 200);

    // The overflowing content is reachable by scrolling, not clipped away.
    expect(find.byType(Scrollable), findsOneWidget);
  });
}
