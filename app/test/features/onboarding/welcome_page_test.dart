import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/onboarding/presentation/welcome_page.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/pump_router.dart';

void main() {
  testWidgets('uses an editorial canvas and compact native product proof', (
    tester,
  ) async {
    await tester.pumpFlui(
      WelcomeView(onStart: () {}, onSignIn: () {}),
      surfaceSize: const Size(390, 844),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scaffold && widget.backgroundColor == FluiColors.cream,
      ),
      findsOneWidget,
    );
    expect(find.text('Habla como quieres sonar.'), findsOneWidget);
    expect(find.text('«Es muy listo, se da cuenta de todo»'), findsOneWidget);
    expect(find.text('«Es muy perspicaz»'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
  Future<GoRouter> pumpWelcome(WidgetTester tester) => pumpRoutedPage(
    tester,
    location: AppRoutes.welcome,
    page: const WelcomePage(),
    otherRoutes: [AppRoutes.intro, AppRoutes.login],
  );

  testWidgets('shows the brand, highlighted tagline and green action', (
    tester,
  ) async {
    await pumpWelcome(tester);

    expect(find.bySemanticsLabel('flui'), findsOneWidget);
    final tagline = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText() == 'Habla como quieres sonar.',
    );
    expect(tagline, findsOneWidget);

    final spans = <TextSpan>[];
    (tester.widget<RichText>(tagline).text as TextSpan).visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    final highlighted = spans.singleWhere((span) => span.text == 'sonar.');
    expect(highlighted.style?.color, FluiColors.charcoal);
    expect(highlighted.style?.backgroundColor, FluiColors.yellowElectric);

    final start = tester.widget<FluiButton>(
      find.widgetWithText(FluiButton, 'Empezar'),
    );
    expect(start.variant, FluiButtonVariant.primary);
    expect(find.text('Ya tengo una cuenta'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, FluiColors.cream);
  });

  testWidgets('Empezar opens the intro', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(find.text('route:/intro'), findsOneWidget);
  });

  testWidgets('Ya tengo una cuenta opens login', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
  });

  testWidgets('Empezar pushes the intro, so the Android back button returns to '
      'welcome instead of exiting the app', (tester) async {
    final router = await pumpWelcome(tester);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    // A push keeps welcome underneath on the Navigator stack; a go()
    // would have replaced it, leaving nothing for the system back
    // button to pop to.
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
    expect(router.routerDelegate.canPop(), isTrue);

    await router.routerDelegate.popRoute();
    await tester.pumpAndSettle();

    expect(find.text('Empezar'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
  });

  testWidgets(
    'Ya tengo una cuenta pushes login, so the Android back button returns '
    'to welcome instead of exiting the app',
    (tester) async {
      final router = await pumpWelcome(tester);

      await tester.tap(find.text('Ya tengo una cuenta'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
      expect(router.routerDelegate.canPop(), isTrue);

      await router.routerDelegate.popRoute();
      await tester.pumpAndSettle();

      expect(find.text('Empezar'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
    },
  );

  testWidgets('fits a small phone without overflow', (tester) async {
    await pumpRoutedPage(
      tester,
      location: AppRoutes.welcome,
      page: const WelcomePage(),
      surfaceSize: const Size(320, 568),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the editorial layout at a 360 logical-pixel width', (
    tester,
  ) async {
    await pumpRoutedPage(
      tester,
      location: AppRoutes.welcome,
      page: const WelcomePage(),
      surfaceSize: const Size(360, 800),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Empezar'), findsOneWidget);
  });

  testWidgets('fits the editorial layout at a 432 logical-pixel width', (
    tester,
  ) async {
    await pumpRoutedPage(
      tester,
      location: AppRoutes.welcome,
      page: const WelcomePage(),
      surfaceSize: const Size(432, 844),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Empezar'), findsOneWidget);
  });

  testWidgets(
    'a viewport shorter than the dock never throws negative constraints',
    (tester) async {
      await pumpRoutedPage(
        tester,
        location: AppRoutes.welcome,
        page: const WelcomePage(),
        surfaceSize: const Size(360, 120),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Empezar'), findsOneWidget);
    },
  );
}
