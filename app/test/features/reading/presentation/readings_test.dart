import 'package:flui/features/reading/presentation/providers/context_readings.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  final perspicaz = seedWord('perspicaz');

  testWidgets('the carousel moves through the scenes', (tester) async {
    await tester.pumpFlui(
      SingleChildScrollView(
        child: ReadingsCarousel(
          readings: perspicaz.readings,
          forms: perspicaz.forms,
        ),
      ),
      surfaceSize: const Size(400, 1000),
    );

    IconButton button(String tooltip) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );

    expect(find.text('1 DE 3'), findsOneWidget);
    expect(find.text('La pregunta que nadie hizo'), findsOneWidget);
    expect(find.text('TRABAJO'), findsOneWidget);
    expect(find.text('ANTES DECÍAS…'), findsOneWidget);
    expect(button('Anterior').onPressed, isNull);

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pump();
    expect(find.text('2 DE 3'), findsOneWidget);
    expect(find.text('Un café con Marta'), findsOneWidget);

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pump();
    expect(find.text('3 DE 3'), findsOneWidget);
    expect(button('Siguiente').onPressed, isNull);

    await tester.tap(find.byTooltip('Anterior'));
    await tester.pump();
    expect(find.text('2 DE 3'), findsOneWidget);
  });

  test('the daily rotation moves the first scene without losing any', () {
    final scenes = ['a', 'b', 'c'];

    expect(rotate(scenes, 0), ['a', 'b', 'c']);
    expect(rotate(scenes, 1), ['b', 'c', 'a']);
    expect(rotate(scenes, 4), ['b', 'c', 'a']);
    expect(rotate(scenes, 2).toSet(), scenes.toSet());
    expect(rotate(const <String>[], 3), isEmpty);
    expect(daysSinceEpoch(day(14)) - daysSinceEpoch(day(13)), 1);
  });
}
