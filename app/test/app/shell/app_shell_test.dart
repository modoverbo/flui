import 'package:flui/app/shell/app_shell_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  const labels = ['Hoy', 'Palabras', 'Habla', 'Tu progreso'];

  Future<List<int>> pumpShell(WidgetTester tester, Size size) async {
    final selected = <int>[];
    await tester.pumpFlui(
      AppShellScaffold(
        selectedIndex: 0,
        onDestinationSelected: selected.add,
        child: const Text('contenido'),
      ),
      surfaceSize: size,
    );
    return selected;
  }

  testWidgets('phones use a bottom navigation bar with 4 destinations', (
    tester,
  ) async {
    final selected = await pumpShell(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    for (final label in labels.take(3)) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Progreso'), findsOneWidget);

    await tester.tap(find.text('Habla'));
    expect(selected, [2]);
    expect(find.text('contenido'), findsOneWidget);

    await tester.tap(find.text('Progreso'));
    expect(selected, [2, 3]);
  });

  testWidgets('phone navigation labels fit inside the clipped bar', (
    tester,
  ) async {
    for (final width in [432.0, 360.0, 320.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      await pumpShell(tester, Size(width, 800));

      expect(find.text('Progreso'), findsOneWidget);
      final progressDestination = tester.widget<NavigationDestination>(
        find.ancestor(
          of: find.text('Progreso'),
          matching: find.byType(NavigationDestination),
        ),
      );
      expect(progressDestination.tooltip, 'Tu progreso');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.hint == 'Tu progreso',
        ),
        findsOneWidget,
      );
      final barRect = tester.getRect(find.byType(NavigationBar));
      final progressLabelRect = tester.getRect(find.text('Progreso'));
      expect(progressLabelRect.left, greaterThanOrEqualTo(barRect.left));
      expect(progressLabelRect.right, lessThanOrEqualTo(barRect.right));
    }
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    final selected = await pumpShell(tester, const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Palabras'));
    expect(selected, [1]);
  });

  testWidgets('tablets use a compact rail', (tester) async {
    await pumpShell(tester, const Size(700, 900));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.destinations, hasLength(4));
  });
}
