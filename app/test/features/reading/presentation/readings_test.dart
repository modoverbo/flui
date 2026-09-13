import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/reading/presentation/reading_page.dart';
import 'package:flui/features/reading/presentation/widgets/readings_carousel.dart';
import 'package:flui/features/vocabulary/domain/word_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_builders.dart';
import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/pump_router.dart';
import '../../../helpers/reduce_motion.dart';

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

    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('La pregunta que nadie hizo'), findsOneWidget);
    expect(find.text('TRABAJO'), findsOneWidget);
    expect(find.text('Antes decías…'), findsOneWidget);
    expect(button('Anterior').onPressed, isNull);

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pump();
    expect(find.text('2 de 3'), findsOneWidget);
    expect(find.text('Un café con Marta'), findsOneWidget);

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pump();
    expect(find.text('3 de 3'), findsOneWidget);
    expect(button('Siguiente').onPressed, isNull);

    await tester.tap(find.byTooltip('Anterior'));
    await tester.pump();
    expect(find.text('2 de 3'), findsOneWidget);
  });

  testWidgets('En contexto filters recent readings by scene', (tester) async {
    final fakes = LearningFakes();
    addTearDown(fakes.dispose);
    await fakes.progress.saveProgress(
      WordProgress.introduced(wordId: perspicaz.id, today: day(12)),
    );
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: AppRoutes.reading,
      page: const ReadingPage(),
      overrides: fakes.overrides,
      surfaceSize: const Size(400, 2000),
    );
    await tester.pumpAndSettle();

    expect(find.text('La pregunta que nadie hizo'), findsOneWidget);
    expect(find.text('Un café con Marta'), findsOneWidget);

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('Un café con Marta'), findsOneWidget);
    expect(find.text('La pregunta que nadie hizo'), findsNothing);
  });

  testWidgets('En contexto is empty before the first word', (tester) async {
    final fakes = LearningFakes();
    addTearDown(fakes.dispose);
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: AppRoutes.reading,
      page: const ReadingPage(),
      overrides: fakes.overrides,
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay escenas.'), findsOneWidget);
  });
}
