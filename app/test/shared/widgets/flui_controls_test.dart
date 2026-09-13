import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_radii.dart';
import 'package:flui/shared/layout/bento_layout.dart';
import 'package:flui/shared/widgets/bento_grid.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flui/shared/widgets/sticky_cta_dock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('FluiButton', () {
    testWidgets('primary is deep green with cream text and handles taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpFlui(
        FluiButton.primary(label: 'Empezar', onPressed: () => taps++),
      );

      await tester.tap(find.text('Empezar'));
      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      expect(taps, 1);
      expect(style.backgroundColor!.resolve({}), FluiColors.greenDeep);
      expect(style.foregroundColor!.resolve({}), FluiColors.cream);
    });

    testWidgets('a primary action is a 14 px rectangle, never a pill', (
      tester,
    ) async {
      await tester.pumpFlui(
        FluiButton.primary(label: 'Empezar', onPressed: () {}),
      );

      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      final shape = style.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, FluiRadii.ctaAll);
      expect(shape.borderRadius, isNot(FluiRadii.pill));
      expect(FluiButton.height, greaterThanOrEqualTo(44));
    });

    testWidgets('accent is yellow with charcoal text, never green', (
      tester,
    ) async {
      await tester.pumpFlui(
        FluiButton.accent(label: 'Empezar', onPressed: () {}),
      );

      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      expect(style.backgroundColor!.resolve({}), FluiColors.yellowElectric);
      expect(style.foregroundColor!.resolve({}), FluiColors.charcoal);
      expect(style.foregroundColor!.resolve({}), isNot(FluiColors.greenDeep));
    });

    testWidgets('outline and text variants render their labels', (
      tester,
    ) async {
      await tester.pumpFlui(
        Column(
          children: [
            FluiButton.outline(label: 'Ver planes', onPressed: () {}),
            FluiButton.text(label: 'Saltar', onPressed: () {}),
          ],
        ),
      );

      expect(find.widgetWithText(OutlinedButton, 'Ver planes'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Saltar'), findsOneWidget);
    });

    testWidgets('loading shows progress and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpFlui(
        FluiButton.primary(
          label: 'Entrar',
          isLoading: true,
          onPressed: () => taps++,
        ),
      );

      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Entrar'), findsOneWidget);
    });
  });

  group('FluiTextField', () {
    testWidgets('password fields toggle visibility', (tester) async {
      await tester.pumpFlui(
        const FluiTextField(
          label: 'Contraseña',
          isPassword: true,
          showPasswordLabel: 'Mostrar contraseña',
          hidePasswordLabel: 'Ocultar contraseña',
        ),
      );

      bool obscured() =>
          tester.widget<TextField>(find.byType(TextField)).obscureText;
      expect(obscured(), isTrue);

      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();

      expect(obscured(), isFalse);
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });

    testWidgets('screen readers get the visible label with the field', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpFlui(
        const FluiTextField(label: 'Correo', hint: 'tu@correo.com'),
      );

      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(label: 'Correo\ntu@correo.com', isTextField: true),
      );
      semantics.dispose();
    });

    testWidgets('shows the label in caps and the error text as written', (
      tester,
    ) async {
      await tester.pumpFlui(
        const FluiTextField(label: 'Correo', errorText: 'Escribe tu correo.'),
      );

      expect(find.text('CORREO'), findsOneWidget);
      expect(find.text('Escribe tu correo.'), findsOneWidget);
    });
  });

  group('FluiLabel', () {
    testWidgets('sets copy in caps but keeps it readable for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpFlui(const FluiLabel('en contexto'));

      expect(find.text('EN CONTEXTO'), findsOneWidget);
      expect(find.bySemanticsLabel('en contexto'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('StateChip', () {
    testWidgets('uses brand colors for each word state', (tester) async {
      await tester.pumpFlui(
        const Column(
          children: [
            StateChip(state: WordStateKind.nueva),
            StateChip(state: WordStateKind.practica),
            StateChip(state: WordStateKind.tuya),
          ],
        ),
      );

      Color background(String label) {
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color!;
      }

      expect(background('NUEVA'), FluiColors.yellowElectric);
      expect(background('PRACTICA'), FluiColors.greenSecondary);
      expect(background('TUYA'), FluiColors.greenDeep);
    });
  });

  group('BentoGrid', () {
    testWidgets('lays tiles out without overlap and reaches a fixed height', (
      tester,
    ) async {
      await tester.pumpFlui(
        const SizedBox(
          width: 360,
          child: BentoGrid(
            tiles: [
              BentoTile(
                span: BentoSpan.large,
                tone: BentoTone.green,
                child: Text('racha'),
              ),
              BentoTile(span: BentoSpan.small, child: Text('a')),
              BentoTile(span: BentoSpan.small, child: Text('b')),
              BentoTile(span: BentoSpan.wide, child: Text('palabra')),
            ],
          ),
        ),
      );

      final anchor = tester.getRect(find.text('racha'));
      final left = tester.getRect(find.text('a'));
      final right = tester.getRect(find.text('b'));
      final wide = tester.getRect(find.text('palabra'));

      expect(anchor.top, lessThan(left.top));
      expect(left.left, lessThan(right.left));
      expect(left.top, closeTo(right.top, 0.5));
      expect(wide.top, greaterThan(left.top));
    });

    testWidgets('an empty bento takes no space', (tester) async {
      await tester.pumpFlui(const BentoGrid(tiles: []));
      expect(tester.getSize(find.byType(BentoGrid)).height, 0);
    });
  });

  group('StickyCtaDock', () {
    testWidgets('keeps the action at the bottom while content scrolls', (
      tester,
    ) async {
      await tester.pumpFlui(
        StickyCtaDock(
          dock: FluiButton.primary(label: 'Empezar', onPressed: () {}),
          child: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 40, child: Text('$i')),
            ],
          ),
        ),
      );

      final before = tester.getRect(find.text('Empezar'));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(tester.getRect(find.text('Empezar')), before);
    });
  });

  testWidgets('molecules render their content', (tester) async {
    var retried = false;
    await tester.pumpFlui(
      SingleChildScrollView(
        child: Column(
          children: [
            const SectionHeader(title: 'Tu plan'),
            const FluiProgressBar(value: 0.4, semanticLabel: 'Progreso'),
            const FluiCard(child: Text('Tarjeta')),
            EmptyState(
              title: 'Muy pronto',
              message: 'Aquí verás tu repertorio crecer.',
              actionLabel: 'Reintentar',
              onAction: () => retried = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('TU PLAN'), findsOneWidget);
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(find.bySemanticsLabel('Progreso'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);
  });
}
