import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/onboarding/presentation/welcome_page.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/pump_router.dart';

void main() {
  testWidgets('shows original voice-world artwork', (tester) async {
    await tester.pumpFlui(
      WelcomeView(onStart: () {}, onSignIn: () {}),
      surfaceSize: const Size(390, 844),
    );
    expect(
      find.image(const AssetImage('assets/textures/flui-voice-world.png')),
      findsOneWidget,
    );
  });
  Future<void> pumpWelcome(WidgetTester tester) => pumpRoutedPage(
    tester,
    location: AppRoutes.welcome,
    page: const WelcomePage(),
    otherRoutes: [AppRoutes.intro, AppRoutes.login],
  );

  testWidgets('shows the brand, tagline and one yellow call to action', (
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
    expect(highlighted.style?.color, FluiColors.yellowElectric);

    final start = tester.widget<FluiButton>(
      find.widgetWithText(FluiButton, 'Empezar'),
    );
    expect(start.variant, FluiButtonVariant.accent);
    expect(find.text('Ya tengo una cuenta'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, FluiColors.greenDeep);
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

  testWidgets('fits a small phone without overflow', (tester) async {
    await pumpRoutedPage(
      tester,
      location: AppRoutes.welcome,
      page: const WelcomePage(),
      surfaceSize: const Size(320, 568),
    );

    expect(tester.takeException(), isNull);
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
