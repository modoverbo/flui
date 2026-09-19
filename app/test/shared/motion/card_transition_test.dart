import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/shared/motion/card_transition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/reduce_motion.dart';

void main() {
  const from = CardPositionState(scale: 1, y: 0, opacity: 1);
  const to = CardPositionState(scale: 0.86, y: 420, opacity: 0, rotation: -0.1);

  testWidgets('settles at the target position once the spring finishes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CardTransition(
          from: from,
          to: to,
          spring: fluiSpringStandard,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(CardTransition),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, closeTo(to.opacity, 0.001));

    final transforms = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(CardTransition),
            matching: find.byType(Transform),
          ),
        )
        .toList();
    // translate, rotate, scale (nesting order in `CardTransition.build`).
    expect(transforms, hasLength(3));
    expect(transforms[0].transform.getTranslation().y, closeTo(to.y, 0.5));
    // getMaxScaleOnAxis() is unreliable in this environment; read the
    // scale matrix's own x-axis column directly instead.
    expect(transforms[2].transform.storage[0], closeTo(to.scale, 0.01));
  });

  testWidgets('calls onComplete once the spring finishes', (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CardTransition(
          from: from,
          to: to,
          spring: fluiSpringStandard,
          onComplete: () => completions++,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(completions, 1);
  });

  testWidgets(
    'settles instantly under reduced motion, with no intermediate frame',
    (tester) async {
      reduceMotion(tester);
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CardTransition(
            from: from,
            to: to,
            spring: fluiSpringStandard,
            onComplete: () => completed = true,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      // The very first frame already reflects `to` -- no animated frame in
      // between, per `docs/redesign/03-card-stack-spec.md` §6.
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(CardTransition),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, to.opacity);
      final translate = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(CardTransition),
              matching: find.byType(Transform),
            ),
          )
          .first;
      expect(translate.transform.getTranslation().y, to.y);

      await tester.pump();
      expect(completed, isTrue);
    },
  );
}
