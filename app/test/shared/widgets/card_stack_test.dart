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

  testWidgets(
    'cards behind the front stay visible even when their own content is '
    'much shorter than the front card (regression: the front card used to '
    'size the whole stack, hiding shorter preview cards completely)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CardStack(
            cards: <Widget>[
              // The front card has tall real content (an exercise); the
              // preview cards have only a couple of lines of text — exactly
              // the mismatch that hid them before the fix.
              SizedBox(
                key: ValueKey('front'),
                height: 700,
                child: ColoredBox(color: Color(0xFFFF0000)),
              ),
              SizedBox(
                key: ValueKey('next'),
                height: 40,
                child: ColoredBox(color: Color(0xFF00FF00)),
              ),
              SizedBox(
                key: ValueKey('next2'),
                height: 20,
                child: ColoredBox(color: Color(0xFF0000FF)),
              ),
            ],
          ),
        ),
      );

      final frontRect = tester.getRect(find.byKey(const ValueKey('front')));
      final nextRect = tester.getRect(find.byKey(const ValueKey('next')));
      final next2Rect = tester.getRect(find.byKey(const ValueKey('next2')));

      // Proof, not just correct transforms: the back cards must actually
      // extend below the front card's own bottom edge on screen.
      expect(
        nextRect.bottom,
        greaterThan(frontRect.bottom),
        reason: 'position 1 must peek out below the front card',
      );
      expect(
        next2Rect.bottom,
        greaterThan(frontRect.bottom),
        reason: 'position 2 must peek out below the front card',
      );
      expect(next2Rect.bottom - frontRect.bottom, greaterThan(0));
    },
  );

  testWidgets('all three cards share the same stable size regardless of '
      'their own content height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CardStack(
          cards: [
            SizedBox(key: ValueKey('front'), height: 900),
            SizedBox(key: ValueKey('next'), height: 10),
            SizedBox(key: ValueKey('next2'), height: 10),
          ],
        ),
      ),
    );

    final frontRect = tester.getRect(find.byKey(const ValueKey('front')));
    final nextRect = tester.getRect(find.byKey(const ValueKey('next')));
    final next2Rect = tester.getRect(find.byKey(const ValueKey('next2')));

    // Unscaled box heights (undo each layer's own scale) must match: a
    // stable geometry, not each card sized to its own content.
    expect(frontRect.height, greaterThan(0));
    expect(nextRect.height / 0.94, closeTo(frontRect.height, 1));
    expect(next2Rect.height / 0.89, closeTo(frontRect.height, 1));
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
