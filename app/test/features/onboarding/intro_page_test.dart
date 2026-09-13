import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/onboarding/presentation/intro_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_router.dart';

void main() {
  Future<void> pumpIntro(WidgetTester tester) => pumpRoutedPage(
    tester,
    location: AppRoutes.intro,
    page: const IntroPage(),
    otherRoutes: [AppRoutes.register],
  );

  testWidgets('walks through three slides to register', (tester) async {
    await pumpIntro(tester);

    expect(
      find.text('No te faltan ideas. Te faltan palabras.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Tú eliges cuánto. flui se adapta.'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Aprende una palabra. Úsala hoy.'), findsOneWidget);

    await tester.tap(find.text('Crear mi cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('route:/register'), findsOneWidget);
  });

  testWidgets('Saltar goes straight to register', (tester) async {
    await pumpIntro(tester);

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    expect(find.text('route:/register'), findsOneWidget);
  });
}
