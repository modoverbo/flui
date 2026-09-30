import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/onboarding/presentation/intro_page.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/shared/motion/feedback_motion.dart';
import 'package:flui/shared/widgets/flui_plate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_router.dart';
import '../../helpers/reduce_motion.dart';

void main() {
  late InMemoryOnboardingStore store;

  setUp(() => store = InMemoryOnboardingStore());

  Future<void> pumpIntro(WidgetTester tester, {Size? size}) async {
    await pumpRoutedPage(
      tester,
      location: AppRoutes.intro,
      page: const IntroPage(),
      otherRoutes: [AppRoutes.plan, AppRoutes.welcome],
      overrides: [onboardingStoreProvider.overrideWithValue(store)],
      surfaceSize: size ?? const Size(420, 1400),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the three benefit headlines emphasize their key phrase in green',
    (tester) async {
      reduceMotion(tester);
      await pumpIntro(tester);

      Color? highlightOf(String plain, String tail) {
        final finder = find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == plain,
        );
        expect(finder, findsOneWidget);
        final spans = <TextSpan>[];
        (tester.widget<RichText>(finder).text as TextSpan).visitChildren((
          span,
        ) {
          if (span is TextSpan && span.text != null) spans.add(span);
          return true;
        });
        return spans.singleWhere((span) => span.text == tail).style?.color;
      }

      expect(
        highlightOf('No te faltan ideas. Te faltan palabras.', 'palabras.'),
        FluiColors.greenDeep,
      );
      await next(tester);
      expect(
        highlightOf('Tú eliges cuánto. flui se adapta.', 'se adapta.'),
        FluiColors.greenDeep,
      );
      await next(tester);
      expect(
        highlightOf('Aprende una palabra. Úsala hoy.', 'Úsala hoy.'),
        FluiColors.greenDeep,
      );
    },
  );

  testWidgets('benefit steps use an editorial paper surface and green action', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpIntro(tester);

    void expectEditorialSurface() {
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        FluiColors.cream,
      );
      expect(find.byType(FluiPlate), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byType(FilledButton).last)
            .style!
            .backgroundColor!
            .resolve(const <WidgetState>{}),
        FluiColors.greenDeep,
      );
    }

    expectEditorialSurface();
    expect(
      tester
          .widget<Text>(
            find.text(
              'flui te ayuda a encontrar la palabra que encaja, '
              'justo cuando la necesitas.',
            ),
          )
          .style!
          .color,
      FluiColors.ink,
    );
    await next(tester);
    expectEditorialSurface();
    await next(tester);
    expectEditorialSurface();
  });

  testWidgets('benefit pages can be swiped one at a time with progress', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpIntro(tester);

    expect(
      find.text('No te faltan ideas. Te faltan palabras.'),
      findsOneWidget,
    );
    expect(find.text('Tú eliges cuánto. flui se adapta.'), findsNothing);
    expect(find.bySemanticsLabel('Paso 1 de 4'), findsOneWidget);

    await tester.fling(
      find.text('No te faltan ideas. Te faltan palabras.'),
      const Offset(-280, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('No te faltan ideas. Te faltan palabras.'), findsNothing);
    expect(find.text('Tú eliges cuánto. flui se adapta.'), findsOneWidget);
    expect(find.text('Aprende una palabra. Úsala hoy.'), findsNothing);
    expect(find.bySemanticsLabel('Paso 2 de 4'), findsOneWidget);
  });

  testWidgets(
    'accessible controls move between benefits and return to welcome',
    (tester) async {
      reduceMotion(tester);
      await pumpIntro(tester);

      await next(tester);
      expect(find.text('Tú eliges cuánto. flui se adapta.'), findsOneWidget);
      expect(find.bySemanticsLabel('Paso 2 de 4'), findsOneWidget);

      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();
      expect(
        find.text('No te faltan ideas. Te faltan palabras.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Paso 1 de 4'), findsOneWidget);

      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();
      expect(find.text('route:/welcome'), findsOneWidget);
    },
  );

  testWidgets('reduced motion swaps to the selected benefit immediately', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpIntro(tester);

    await tester.fling(
      find.text('No te faltan ideas. Te faltan palabras.'),
      const Offset(-280, 0),
      1000,
    );
    await tester.pump();

    expect(find.text('Tú eliges cuánto. flui se adapta.'), findsOneWidget);
    expect(find.text('No te faltan ideas. Te faltan palabras.'), findsNothing);
  });

  testWidgets(
    'benefit transitions slide in their direction and expose one page',
    (tester) async {
      await pumpIntro(tester);

      final firstPage = find.text('No te faltan ideas. Te faltan palabras.');
      final secondPage = find.text('Tú eliges cuánto. flui se adapta.');
      final firstCenter = tester.getCenter(firstPage);

      await tester.tap(find.text('Seguir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      expect(
        find.bySemanticsLabel(RegExp(r'^No te faltan ideas\.')),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Tú eliges cuánto\.')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Paso 2 de 4'), findsOneWidget);
      expect(tester.getCenter(firstPage).dx, lessThan(firstCenter.dx));
      expect(tester.getCenter(secondPage).dx, greaterThan(firstCenter.dx));
    },
  );

  testWidgets('benefit back and lesson boundary preserve the four-step order', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpIntro(tester);

    await next(tester);
    await next(tester);
    expect(find.text('Aprende una palabra. Úsala hoy.'), findsOneWidget);

    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Tú eliges cuánto. flui se adapta.'), findsOneWidget);

    await next(tester);
    await next(tester);
    final word = seedWords.first;
    expect(find.text(word.lemma), findsWidgets);

    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Aprende una palabra. Úsala hoy.'), findsOneWidget);
  });

  testWidgets('no slide ships a pastel icon tile', (tester) async {
    reduceMotion(tester);
    await pumpIntro(tester);

    expect(
      find.byWidgetPredicate((w) => w is Icon && (w.size ?? 24) >= 32),
      findsNothing,
      reason: 'the 40 px icon inside a squircle is gone',
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == FluiColors.greenTint,
      ),
      findsNothing,
      reason: 'no pastel tile behind anything',
    );
  });

  testWidgets('the micro-lesson uses a real word and only then lets you on', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpIntro(tester);
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }

    final word = seedWords.first;
    expect(find.text(word.lemma), findsWidgets);
    expect(find.text('«${word.replaces.first.before}»'), findsOneWidget);

    final seePlan = find.text('Ver mi plan');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );

    // A wrong answer shakes and marks, it never says "incorrecto".
    final wrong = word.exercises.first.options.firstWhere((o) => !o.isCorrect);
    await tester.tap(find.text(wrong.text));
    await tester.pumpAndSettle();
    expect(find.text('Casi. Mira la frase otra vez.'), findsOneWidget);
    expect(find.byType(ShakeBox), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    final wrongChoice = tester.widget<Material>(
      find
          .ancestor(of: find.text(wrong.text), matching: find.byType(Material))
          .first,
    );
    expect(
      (wrongChoice.shape! as RoundedRectangleBorder).side.color,
      FluiColors.ink,
    );
    expect((wrongChoice.shape! as RoundedRectangleBorder).side.width, 2);

    await tester.tap(find.text(word.exercises.first.correctOption.text).last);
    await tester.pumpAndSettle();

    expect(find.text('Eso. Suena distinto, ¿no?'), findsOneWidget);
    expect(find.text('«${word.replaces.first.after}»'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNotNull,
    );

    await tester.tap(seePlan);
    await tester.pumpAndSettle();
    expect(find.text('route:/plan'), findsOneWidget);
  });

  testWidgets('Saltar goes straight to the plan', (tester) async {
    reduceMotion(tester);
    await pumpIntro(tester);

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    expect(find.text('route:/plan'), findsOneWidget);
  });

  testWidgets('the lesson card fits at 130 % text on a narrow phone', (
    tester,
  ) async {
    reduceMotion(tester);
    scaleText(tester, 1.3);
    await pumpIntro(tester, size: const Size(320, 780));
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    expect(tester.takeException(), isNull);
    final correct = seedWords.first.exercises.first.correctOption.text;
    await tester.ensureVisible(find.text(correct).last);
    expect(find.text(correct), findsWidgets);
    expect(find.text('Ver mi plan'), findsOneWidget);
    expect(
      tester.getRect(find.text('Ver mi plan')).bottom,
      lessThanOrEqualTo(780),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a viewport shorter than the dock never throws negative constraints',
    (tester) async {
      reduceMotion(tester);
      await pumpIntro(tester, size: const Size(360, 120));

      expect(tester.takeException(), isNull);
      expect(find.text('Seguir'), findsOneWidget);
    },
  );

  testWidgets('never shows the retired preference-question screens, going '
      'straight from the third benefit slide to the micro-lesson', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpIntro(tester);
    expect(find.bySemanticsLabel('Paso 1 de 4'), findsOneWidget);

    await next(tester);
    expect(find.bySemanticsLabel('Paso 2 de 4'), findsOneWidget);
    await next(tester);
    expect(find.bySemanticsLabel('Paso 3 de 4'), findsOneWidget);
    await next(tester);

    expect(find.text('¿Dónde te traiciona el vocabulario?'), findsNothing);
    expect(find.text('¿Cómo quieres sonar?'), findsNothing);
    expect(find.bySemanticsLabel('Paso 4 de 4'), findsOneWidget);
    final word = seedWords.first;
    expect(find.text(word.lemma), findsWidgets);
  });
}
