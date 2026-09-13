import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_motion.dart';
import 'package:flui/shared/motion/feedback_motion.dart';
import 'package:flui/shared/motion/reveal_lines.dart';
import 'package:flui/shared/motion/section_entrance.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [child] with animations on or off, in the flui-free minimum a
/// motion widget needs.
Future<void> pumpMotion(
  WidgetTester tester,
  Widget child, {
  required bool animations,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: !animations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('RevealLines', () {
    testWidgets('slides each line up, one stagger behind the last', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        const RevealLines(children: [Text('uno'), Text('dos')]),
        animations: true,
      );

      double opacityOf(String text) => tester
          .widget<Opacity>(
            find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
          )
          .opacity;

      expect(opacityOf('uno'), lessThan(1));
      expect(opacityOf('dos'), lessThanOrEqualTo(opacityOf('uno')));

      await tester.pumpAndSettle();
      expect(opacityOf('uno'), 1);
      expect(opacityOf('dos'), 1);
    });

    testWidgets('is simply there with reduced motion', (tester) async {
      await pumpMotion(
        tester,
        const RevealLines(children: [Text('uno'), Text('dos')]),
        animations: false,
      );

      for (final opacity in tester.widgetList<Opacity>(find.byType(Opacity))) {
        expect(opacity.opacity, 1);
      }
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('DrawUnderline', () {
    testWidgets('draws left to right in 220 ms', (tester) async {
      await pumpMotion(
        tester,
        const DrawUnderline(drawn: false, haptic: false, child: Text('sí')),
        animations: true,
      );
      await pumpMotion(
        tester,
        const DrawUnderline(drawn: true, haptic: false, child: Text('sí')),
        animations: true,
      );

      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(FluiMotion.underlineDraw);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is drawn at once with reduced motion', (tester) async {
      await pumpMotion(
        tester,
        const DrawUnderline(drawn: false, haptic: false, child: Text('sí')),
        animations: false,
      );
      await pumpMotion(
        tester,
        const DrawUnderline(drawn: true, haptic: false, child: Text('sí')),
        animations: false,
      );

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('sí'), findsOneWidget);
    });
  });

  group('ShakeBox', () {
    testWidgets('shakes and takes an amber border, never a red one', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        const ShakeBox(attempt: 0, child: Text('opciones')),
        animations: true,
      );
      final resting = tester.getTopLeft(find.text('opciones')).dx;

      Border borderOf() =>
          (tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
                      as BoxDecoration)
                  .border!
              as Border;
      expect(borderOf().top.color, Colors.transparent);

      await pumpMotion(
        tester,
        const ShakeBox(attempt: 1, child: Text('opciones')),
        animations: true,
      );
      expect(tester.hasRunningAnimations, isTrue);
      expect(borderOf().top.color, FluiColors.amber);

      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester.getTopLeft(find.text('opciones')).dx,
        isNot(closeTo(resting, 0.5)),
        reason: 'the box moves while it shakes',
      );

      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('opciones')).dx,
        closeTo(resting, 0.01),
        reason: 'and comes back to where it was',
      );
    });

    testWidgets('marks without moving under reduced motion', (tester) async {
      await pumpMotion(
        tester,
        const ShakeBox(attempt: 0, child: Text('opciones')),
        animations: false,
      );
      final resting = tester.getTopLeft(find.text('opciones'));

      await pumpMotion(
        tester,
        const ShakeBox(attempt: 1, child: Text('opciones')),
        animations: false,
      );

      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getTopLeft(find.text('opciones')), resting);
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
              as BoxDecoration;
      expect((decoration.border! as Border).top.color, FluiColors.amber);
    });
  });

  group('FluiProgressBar', () {
    testWidgets('eases to its new value and stands still when asked to', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        const SizedBox(
          width: 200,
          child: FluiProgressBar(value: 0.2, semanticLabel: 'Progreso'),
        ),
        animations: true,
      );
      await tester.pumpAndSettle();

      await pumpMotion(
        tester,
        const SizedBox(
          width: 200,
          child: FluiProgressBar(value: 0.9, semanticLabel: 'Progreso'),
        ),
        animations: true,
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();

      await pumpMotion(
        tester,
        const SizedBox(
          width: 200,
          child: FluiProgressBar(value: 0.2, semanticLabel: 'Progreso'),
        ),
        animations: false,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reports its value to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpMotion(
        tester,
        const SizedBox(
          width: 200,
          child: FluiProgressBar(value: 0.4, semanticLabel: 'Progreso'),
        ),
        animations: false,
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Progreso')),
        isSemantics(label: 'Progreso', value: '40 %'),
      );
      semantics.dispose();
    });
  });

  group('SectionEntrance', () {
    testWidgets('fades and rises, staggered by its index', (tester) async {
      await pumpMotion(
        tester,
        const Column(
          children: [
            SectionEntrance(child: Text('uno')),
            SectionEntrance(index: 1, child: Text('dos')),
          ],
        ),
        animations: true,
      );

      expect(find.byType(Animate), findsNWidgets(2));
      await tester.pumpAndSettle();
      expect(find.text('uno'), findsOneWidget);
      expect(find.text('dos'), findsOneWidget);
    });

    testWidgets('adds nothing at all with reduced motion', (tester) async {
      await pumpMotion(
        tester,
        const SectionEntrance(child: Text('uno')),
        animations: false,
      );

      expect(find.byType(Animate), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('uno'), findsOneWidget);
    });
  });
}
