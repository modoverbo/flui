import 'package:flui/app/shell/app_shell_scaffold.dart';
import 'package:flui/app/shell/flui_bottom_bar.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  const labels = ['Hoy', 'Entrenar', 'Palabras', 'Tu progreso'];

  Future<List<int>> pumpShell(
    WidgetTester tester,
    Size size, {
    List<Override> overrides = const [],
  }) async {
    final selected = <int>[];
    await tester.pumpFlui(
      AppShellScaffold(
        selectedIndex: 0,
        onDestinationSelected: selected.add,
        child: const Text('contenido'),
      ),
      overrides: overrides,
      surfaceSize: size,
    );
    return selected;
  }

  testWidgets('phones show FluiBottomBar (not the M3 NavigationBar) with '
      'Hoy/Entrenar/Palabras/Progreso', (tester) async {
    final selected = await pumpShell(tester, const Size(400, 800));

    expect(find.byType(FluiBottomBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationDestination), findsNothing);
    for (final label in labels.take(3)) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Habla'), findsNothing);

    await tester.tap(find.text('Entrenar'));
    expect(selected, [1]);

    await tester.tap(find.text('Palabras'));
    expect(selected, [1, 2]);
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    final selected = await pumpShell(tester, const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(FluiBottomBar), findsNothing);
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Palabras'));
    expect(selected, [2]);
  });

  testWidgets('tablets use a compact rail', (tester) async {
    await pumpShell(tester, const Size(700, 900));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.destinations, hasLength(4));
  });
}
