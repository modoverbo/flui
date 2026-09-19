import 'package:flui/shared/widgets/editorial_stat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders the number and its label', (tester) async {
    await tester.pumpFlui(
      const SizedBox(
        width: 160,
        child: EditorialStat(value: '12', label: 'días activos'),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('DÍAS ACTIVOS'), findsOneWidget);
  });

  testWidgets('renders an optional caption under the label', (tester) async {
    await tester.pumpFlui(
      const SizedBox(
        width: 160,
        child: EditorialStat(
          value: '84 %',
          label: 'precisión',
          caption: 'últimos 30 días',
        ),
      ),
    );

    expect(find.text('últimos 30 días'), findsOneWidget);
  });

  testWidgets('is tappable when onTap is given, and not otherwise', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpFlui(
      SizedBox(
        width: 160,
        child: EditorialStat(value: '3', label: 'repasos', onTap: () => taps++),
      ),
    );

    expect(find.byType(InkWell), findsOneWidget);
    await tester.tap(find.text('3'));
    expect(taps, 1);
  });

  testWidgets('has no InkWell when onTap is null', (tester) async {
    await tester.pumpFlui(
      const SizedBox(
        width: 160,
        child: EditorialStat(value: '3', label: 'repasos'),
      ),
    );

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a single semantics node carries the full reading', (
    tester,
  ) async {
    await tester.pumpFlui(
      const SizedBox(
        width: 160,
        child: EditorialStat(
          value: '12',
          label: 'días activos',
          semanticLabel: '12 días activos esta racha',
        ),
      ),
    );

    expect(find.bySemanticsLabel('12 días activos esta racha'), findsOneWidget);
  });

  testWidgets('the numeral shrinks to fit a narrow width at 130 % text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpFlui(
      const SizedBox(
        width: 100,
        child: EditorialStat(value: '1234', label: 'palabras tuyas'),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
