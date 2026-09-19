import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/onboarding/presentation/intro_page.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/vocabulary/data/fake/seed_content.dart';
import 'package:flui/shared/motion/feedback_motion.dart';
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

  testWidgets('the three slides set the key noun in yellow', (tester) async {
    reduceMotion(tester);
    await pumpIntro(tester);

    Color? highlightOf(String plain, String tail) {
      final finder = find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == plain,
      );
      expect(finder, findsOneWidget);
      final spans = <TextSpan>[];
      (tester.widget<RichText>(finder).text as TextSpan).visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });
      return spans.singleWhere((span) => span.text == tail).style?.color;
    }

    expect(
      highlightOf('No te faltan ideas. Te faltan palabras.', 'palabras.'),
      FluiColors.yellowElectric,
    );
    await next(tester);
    expect(
      highlightOf('Tú eliges cuánto. flui se adapta.', 'se adapta.'),
      FluiColors.yellowElectric,
    );
    await next(tester);
    expect(
      highlightOf('Aprende una palabra. Úsala hoy.', 'Úsala hoy.'),
      FluiColors.yellowElectric,
    );
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

  testWidgets('the two questions gate the way forward and are saved', (
    tester,
  ) async {
    reduceMotion(tester);
    await pumpIntro(tester);
    await next(tester);
    await next(tester);
    await next(tester);

    expect(find.text('¿Dónde te traiciona el vocabulario?'), findsOneWidget);
    FilledButton cta() =>
        tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(cta().onPressed, isNull);

    await tester.tap(find.text('Trabajo'));
    await tester.pumpAndSettle();
    expect(cta().onPressed, isNotNull);
    await next(tester);

    expect(find.text('¿Cómo quieres sonar?'), findsOneWidget);
    expect(cta().onPressed, isNull);
    await tester.tap(find.text('Preciso'));
    await tester.pumpAndSettle();
    expect(cta().onPressed, isNotNull);

    expect(
      await store.readAnswers(),
      const OnboardingAnswers(
        contexts: {Scene.trabajo},
        tone: SpeakingTone.precise,
      ),
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
    await tester.tap(find.text('Trabajo'));
    await tester.pumpAndSettle();
    await next(tester);
    await tester.tap(find.text('Preciso'));
    await tester.pumpAndSettle();
    await next(tester);

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

  testWidgets('fits at 130 % text size on a phone', (tester) async {
    reduceMotion(tester);
    scaleText(tester, 1.3);
    await pumpIntro(tester, size: const Size(360, 780));

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
}
