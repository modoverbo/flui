import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/shared/widgets/empty_state.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_card.dart';
import 'package:flui/shared/widgets/flui_progress_bar.dart';
import 'package:flui/shared/widgets/flui_text_field.dart';
import 'package:flui/shared/widgets/section_header.dart';
import 'package:flui/shared/widgets/stat_tile.dart';
import 'package:flui/shared/widgets/state_chip.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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

    testWidgets('accent is yellow with charcoal text', (tester) async {
      await tester.pumpFlui(
        FluiButton.accent(label: 'Empezar', onPressed: () {}),
      );

      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      expect(style.backgroundColor!.resolve({}), FluiColors.yellowElectric);
      expect(style.foregroundColor!.resolve({}), FluiColors.charcoal);
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

    testWidgets('shows the label and the error text', (tester) async {
      await tester.pumpFlui(
        const FluiTextField(label: 'Correo', errorText: 'Escribe tu correo.'),
      );

      expect(find.text('Correo'), findsOneWidget);
      expect(find.text('Escribe tu correo.'), findsOneWidget);
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

      expect(background('Nueva'), FluiColors.yellowElectric);
      expect(background('Practica'), FluiColors.greenSecondary);
      expect(background('Tuya'), FluiColors.greenDeep);
      expect(find.byIcon(LucideIcons.sparkles), findsOneWidget);
    });
  });

  testWidgets('molecules render their content', (tester) async {
    var retried = false;
    await tester.pumpFlui(
      SingleChildScrollView(
        child: Column(
          children: [
            const SectionHeader(title: 'Tu plan'),
            const StatTile(value: '5 de 7', label: 'días esta semana'),
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

    expect(find.text('Tu plan'), findsOneWidget);
    expect(find.text('5 de 7'), findsOneWidget);
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(find.bySemanticsLabel('Progreso'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);
  });
}
