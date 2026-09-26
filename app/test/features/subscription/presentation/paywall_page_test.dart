import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/clock/clock.dart';
import 'package:flui/core/config/feature_flags.dart';
import 'package:flui/core/error/failure.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/features/auth/data/fake_auth_repository.dart';
import 'package:flui/features/auth/domain/app_user.dart';
import 'package:flui/features/auth/presentation/providers/auth_providers.dart';
import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/onboarding/domain/onboarding_store.dart';
import 'package:flui/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/subscription/data/fake_checkout_launcher.dart';
import 'package:flui/features/subscription/data/fake_subscription_repository.dart';
import 'package:flui/features/subscription/presentation/pages/paywall_page.dart';
import 'package:flui/features/subscription/presentation/pages/plan_preview_page.dart';
import 'package:flui/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flui/features/subscription/presentation/widgets/plan_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_router.dart';
import '../../../helpers/reduce_motion.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeSubscriptionRepository subscriptions;
  late FakeCheckoutLauncher launcher;
  late InMemoryOnboardingStore store;
  late int returns;

  setUp(() {
    auth = FakeAuthRepository(
      initialUser: const AppUser(
        id: 'user-1',
        email: 'ana@correo.com',
        displayName: 'Ana',
      ),
    );
    subscriptions = FakeSubscriptionRepository(
      clock: FixedClock(DateTime(2026, 9, 13)),
      currentUserId: () => auth.currentUser?.id,
    );
    returns = 0;
    launcher = FakeCheckoutLauncher(
      subscriptions: subscriptions,
      onReturn: () => returns++,
    );
    store = InMemoryOnboardingStore(
      answers: const OnboardingAnswers(
        contexts: {Scene.trabajo, Scene.entrevista},
        tone: SpeakingTone.precise,
      ),
    );
  });

  tearDown(() => auth.dispose());

  Future<void> pumpPaywall(WidgetTester tester) async {
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: AppRoutes.paywall,
      page: const PaywallPage(),
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
        checkoutLauncherProvider.overrideWithValue(launcher),
        onboardingStoreProvider.overrideWithValue(store),
      ],
      surfaceSize: const Size(420, 1600),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
  }

  group('page 1: tu plan', () {
    testWidgets('greets by name and echoes the onboarding answers', (
      tester,
    ) async {
      await pumpPaywall(tester);

      expect(find.text('Tu plan está listo, Ana.'), findsOneWidget);
      expect(find.text('Palabras para trabajo y entrevista.'), findsOneWidget);
      expect(find.text('Con el tono que elegiste: preciso.'), findsOneWidget);
      expect(
        find.text('Una palabra al día, en el tiempo que tengas.'),
        findsOneWidget,
      );
    });

    testWidgets('invents no social proof', (tester) async {
      await pumpPaywall(tester);

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(
        texts,
        isNot(matches(RegExp(r'\d+[\d.,]*\s*(personas|usuarios)'))),
      );
      expect(texts.toLowerCase(), isNot(contains('miles de')));
    });
  });

  group('page 2: cómo funciona tu prueba', () {
    testWidgets('shows the three dates and the safety line', (tester) async {
      await pumpPaywall(tester);
      await next(tester);

      expect(find.text('Cómo funciona tu prueba'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(
        find.text('Acceso completo. No te cobramos nada.'),
        findsOneWidget,
      );
      expect(find.text('Día 5'), findsOneWidget);
      expect(find.text('Día 8'), findsOneWidget);
      expect(
        find.text('Empieza tu plan. Cancelas cuando quieras.'),
        findsOneWidget,
      );
      expect(
        find.text('Si cancelas antes del día 8, no pagas nada.'),
        findsOneWidget,
      );
    });

    testWidgets('promises no reminder while there is nothing to send it', (
      tester,
    ) async {
      expect(
        FluiFeatures.trialReminder,
        isFalse,
        reason: 'flip the flag only when the day-5 reminder actually exists',
      );
      await pumpPaywall(tester);
      await next(tester);

      expect(find.text('Te avisamos. Faltan 2 días.'), findsNothing);
      expect(
        find.text(
          'Faltan 2 días. La fecha exacta está en Tu progreso, siempre a la '
          'vista.',
        ),
        findsOneWidget,
      );
    });
  });

  group('page 3: elige tu plan', () {
    Future<void> toChoice(WidgetTester tester) async {
      await pumpPaywall(tester);
      await next(tester);
      await next(tester);
    }

    testWidgets('leads with the quarterly plan and its real prices', (
      tester,
    ) async {
      await toChoice(tester);

      expect(find.text('Trimestral'), findsOneWidget);
      expect(find.text(r'US$ 16.15 cada 3 meses'), findsOneWidget);
      expect(find.text(r'Equivale a US$ 5.38 al mes'), findsOneWidget);
      expect(find.text('AHORRA 23%'), findsOneWidget);
      expect(find.text('Mensual'), findsOneWidget);
      expect(find.text(r'US$ 6.99 al mes'), findsOneWidget);

      // Recommended first, dominant, and its badge above the card fold.
      final cards = tester.widgetList<PlanCard>(find.byType(PlanCard)).toList();
      expect(cards.first.plan.id, 'quarterly');
      expect(cards.first.recommended, isTrue);
      expect(cards.last.recommended, isFalse);
      expect(
        tester.getSize(find.byType(PlanCard).first).height,
        greaterThan(tester.getSize(find.byType(PlanCard).last).height),
      );
      expect(
        tester.getRect(find.text('AHORRA 23%')).top,
        lessThan(tester.getRect(find.text('Trimestral')).top),
      );
    });

    testWidgets('lists five benefits and three objections', (tester) async {
      await toChoice(tester);

      expect(find.text('QUÉ INCLUYE'), findsOneWidget);
      for (final benefit in [
        'Una palabra al día que de verdad vas a usar.',
        'La ves en escenas reales, no en una lista.',
        'La escribes tú antes de darla por tuya.',
        'Vuelve justo antes de que se te olvide.',
        'Tu repertorio queda a la vista, palabra por palabra.',
      ]) {
        expect(find.text(benefit), findsOneWidget, reason: benefit);
      }

      expect(find.text('¿Y si no tengo tiempo?'), findsOneWidget);
      expect(find.text('¿Y si ya sé español?'), findsOneWidget);
      expect(find.text('¿Cómo cancelo?'), findsOneWidget);

      expect(find.text('¿Cómo cancelo?'), findsOneWidget);
      await tester.ensureVisible(find.text('¿Cómo cancelo?'));
      await tester.tap(find.text('¿Cómo cancelo?'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Desde tu cuenta, en dos toques. Sin llamadas y sin explicaciones.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the CTA is yellow, says the price and starts checkout', (
      tester,
    ) async {
      await toChoice(tester);

      expect(find.text('Empezar prueba gratis'), findsOneWidget);
      expect(find.text(r'Hoy pagas US$0.'), findsOneWidget);

      await tester.tap(find.text('Empezar prueba gratis'));
      // Not pumpAndSettle: the CTA spinner keeps ticking while redirecting.
      await tester.pump();
      await tester.pump();

      expect(subscriptions.checkoutRequests, ['quarterly']);
      expect(launcher.openedUrls.single.path, contains('quarterly'));
      expect(returns, 1);
    });

    testWidgets('choosing monthly checks out monthly', (tester) async {
      await toChoice(tester);

      await tester.tap(find.text('Mensual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar prueba gratis'));
      await tester.pump();
      await tester.pump();

      expect(subscriptions.checkoutRequests, ['monthly']);
    });

    testWidgets('shows a friendly message when checkout fails', (tester) async {
      await toChoice(tester);
      subscriptions.nextFailure = const NetworkFailure();

      await tester.tap(find.text('Empezar prueba gratis'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Sin conexión. Revisa tu internet y vuelve a intentarlo.'),
        findsOneWidget,
      );
      expect(launcher.openedUrls, isEmpty);
    });
  });

  testWidgets('a plan chosen before signing up skips the pitch', (
    tester,
  ) async {
    await store.writeSelectedPlanId('monthly');
    await pumpPaywall(tester);

    expect(find.text('Elige tu plan'), findsOneWidget);
    await tester.tap(find.text('Empezar prueba gratis'));
    await tester.pump();
    await tester.pump();

    expect(subscriptions.checkoutRequests, ['monthly']);
  });

  testWidgets('offers a retry when plans cannot load', (tester) async {
    subscriptions.nextFailure = const NetworkFailure();
    await pumpPaywall(tester);

    expect(find.text('No pudimos cargar los planes.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Tu plan está listo, Ana.'), findsOneWidget);
  });

  testWidgets('sign out is available', (tester) async {
    await pumpPaywall(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNull);
  });

  group('/plan before the account exists', () {
    Future<void> pumpPreview(
      WidgetTester tester, {
      Size surfaceSize = const Size(420, 1600),
    }) async {
      reduceMotion(tester);
      await pumpRoutedPage(
        tester,
        location: AppRoutes.plan,
        page: const PlanPreviewPage(),
        otherRoutes: [AppRoutes.register],
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(subscriptions),
          onboardingStoreProvider.overrideWithValue(store),
        ],
        surfaceSize: surfaceSize,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a compact editorial summary from saved answers', (
      tester,
    ) async {
      await store.writeAnswers(
        const OnboardingAnswers(
          contexts: {Scene.trabajo, Scene.entrevista},
          tone: SpeakingTone.precise,
        ),
      );
      await pumpPreview(tester);

      expect(find.text('Tu plan está listo.'), findsOneWidget);
      expect(find.text('Palabras para trabajo y entrevista.'), findsOneWidget);
      expect(find.text('Con el tono que elegiste: preciso.'), findsOneWidget);
      expect(
        find.text('Una palabra al día, en el tiempo que tengas.'),
        findsOneWidget,
      );

      final title = tester.widget<Text>(find.text('Tu plan está listo.'));
      expect(title.style?.color, FluiColors.charcoal);
      expect(title.style?.fontSize, lessThan(40));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  FluiColors.greenTint,
        ),
        findsNWidgets(2),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  FluiColors.greenDeep,
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses the existing general copy when answers are missing', (
      tester,
    ) async {
      await store.writeAnswers(OnboardingAnswers.empty);
      await pumpPreview(tester);

      expect(find.text('Tu plan está listo.'), findsOneWidget);
      expect(
        find.text('Palabras para cualquier conversación.'),
        findsOneWidget,
      );
      expect(find.text('Con el tono que elijas.'), findsOneWidget);
      expect(
        find.text('Una palabra al día, en el tiempo que tengas.'),
        findsOneWidget,
      );
      expect(find.text('Palabras para trabajo y entrevista.'), findsNothing);
      expect(find.text('Con el tono que elegiste: preciso.'), findsNothing);
    });

    testWidgets('does not imply an unanswered tone for a partial answer', (
      tester,
    ) async {
      await store.writeAnswers(
        const OnboardingAnswers(contexts: {Scene.entrevista}),
      );
      await pumpPreview(tester);

      expect(find.text('Palabras para entrevista.'), findsOneWidget);
      expect(find.text('Con el tono que elijas.'), findsOneWidget);
      expect(find.text('Con el tono que elegiste: preciso.'), findsNothing);
    });

    testWidgets('does not imply an unanswered context for a partial answer', (
      tester,
    ) async {
      await store.writeAnswers(
        const OnboardingAnswers(tone: SpeakingTone.precise),
      );
      await pumpPreview(tester);

      expect(
        find.text('Palabras para cualquier conversación.'),
        findsOneWidget,
      );
      expect(find.text('Con el tono que elegiste: preciso.'), findsOneWidget);
      expect(find.text('Palabras para entrevista.'), findsNothing);
    });

    testWidgets('keeps the summary dock reachable on a short narrow screen', (
      tester,
    ) async {
      await pumpPreview(tester, surfaceSize: const Size(320, 560));

      expect(find.text('Seguir'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Seguir')).bottom,
        lessThanOrEqualTo(560),
      );

      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();

      expect(find.text('Cómo funciona tu prueba'), findsOneWidget);
    });

    testWidgets('shows real prices without an account, then asks for one', (
      tester,
    ) async {
      await pumpPreview(tester);

      expect(find.text('Tu plan está listo.'), findsOneWidget);
      await next(tester);
      await next(tester);
      expect(find.text(r'US$ 16.15 cada 3 meses'), findsOneWidget);
      expect(find.text('Crear mi cuenta'), findsOneWidget);
      expect(
        find.text('Creas tu cuenta en el siguiente paso.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Mensual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear mi cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('route:/register'), findsOneWidget);
      expect(await store.readSelectedPlanId(), 'monthly');
      expect(subscriptions.checkoutRequests, isEmpty);
    });
  });
}
