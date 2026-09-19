import 'package:flui/shared/widgets/card_stack.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/reduce_motion.dart';

void main() {
  List<Widget> threeCards() => const [
    SizedBox(key: ValueKey('front'), width: 100, height: 100),
    SizedBox(key: ValueKey('next'), width: 100, height: 100),
    SizedBox(key: ValueKey('next2'), width: 100, height: 100),
  ];

  testWidgets('rest geometry matches the spec table exactly', (tester) async {
    expect(CardStack.restState(0).scale, 1.00);
    expect(CardStack.restState(0).y, 0);
    expect(CardStack.restState(0).opacity, 1.00);

    expect(CardStack.restState(1).scale, 0.94);
    expect(CardStack.restState(1).y, 18);
    expect(CardStack.restState(1).opacity, 0.85);

    expect(CardStack.restState(2).scale, 0.89);
    expect(CardStack.restState(2).y, 34);
    expect(CardStack.restState(2).opacity, 0.55);
  });

  testWidgets('composites the front card plus the next two at spec geometry', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: CardStack(cards: threeCards())));

    // `_buildStatic` paints back-to-front: position 2, then 1, then the
    // front, so widget-tree traversal order matches that. Scoped to
    // `CardStack`'s own subtree so MaterialApp/route scaffolding (which has
    // Transforms of its own) can't shift the indices.
    final opacities = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(CardStack),
            matching: find.byType(Opacity),
          ),
        )
        .toList();
    expect(opacities, hasLength(3));
    expect(opacities[0].opacity, 0.55);
    expect(opacities[1].opacity, 0.85);
    expect(opacities[2].opacity, 1.00);

    final transforms = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(CardStack),
            matching: find.byType(Transform),
          ),
        )
        .toList();
    expect(transforms, hasLength(6));
    // [translate2, scale2, translate1, scale1, translate0, scale0].
    // getMaxScaleOnAxis() is unreliable in this environment; read the scale
    // matrix's own x-axis column directly instead.
    expect(transforms[0].transform.getTranslation().y, 34);
    expect(transforms[1].transform.storage[0], closeTo(0.89, 0.001));
    expect(transforms[2].transform.getTranslation().y, 18);
    expect(transforms[3].transform.storage[0], closeTo(0.94, 0.001));
    expect(transforms[4].transform.getTranslation().y, 0);
    expect(transforms[5].transform.storage[0], closeTo(1.00, 0.001));

    // Only the front card is interactive. Matched by predicate (not just
    // type) since MaterialApp's own scaffolding adds harmless
    // `IgnorePointer(ignoring: false)` ancestors of its own.
    Finder ignoringAncestorOf(String key) => find.ancestor(
      of: find.byKey(ValueKey(key)),
      matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
    );
    expect(ignoringAncestorOf('front'), findsNothing);
    expect(ignoringAncestorOf('next'), findsWidgets);
    expect(ignoringAncestorOf('next2'), findsWidgets);
  });

  testWidgets('only the front card renders under reduced motion, full-bleed', (
    tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(MaterialApp(home: CardStack(cards: threeCards())));

    expect(find.byKey(const ValueKey('front')), findsOneWidget);
    expect(find.byKey(const ValueKey('next')), findsNothing);
    expect(find.byKey(const ValueKey('next2')), findsNothing);
  });

  testWidgets('a front-card key change plays the transition, then settles', (
    tester,
  ) async {
    var completions = 0;
    Widget build(List<Widget> cards) => MaterialApp(
      home: CardStack(
        cards: cards,
        onFrontCardExitComplete: () => completions++,
      ),
    );

    await tester.pumpWidget(build(threeCards()));
    await tester.pumpWidget(
      build(const [
        SizedBox(key: ValueKey('front2'), width: 100, height: 100),
        SizedBox(key: ValueKey('next3'), width: 100, height: 100),
      ]),
    );
    // Mid-flight: both the old front card and the newly promoted one exist.
    expect(find.byKey(const ValueKey('front')), findsOneWidget);
    expect(find.byKey(const ValueKey('front2')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(completions, 1);
    expect(find.byKey(const ValueKey('front')), findsNothing);
    expect(find.byKey(const ValueKey('front2')), findsOneWidget);
  });
}
