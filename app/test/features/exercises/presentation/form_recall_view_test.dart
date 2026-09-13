import 'package:flui/features/exercises/domain/form_recall_check.dart';
import 'package:flui/features/exercises/presentation/widgets/form_recall_view.dart';
import 'package:flui/features/vocabulary/domain/form_recall_prompt.dart';
import 'package:flui/features/vocabulary/domain/word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_app.dart';

class _RecallHost extends StatefulWidget {
  const new();

  @override
  State<_RecallHost> createState() => _RecallHostState();
}

class _RecallHostState extends State<_RecallHost> {
  final Word _word = seedWord('perspicaz');
  late final _prompt = FormRecallPrompt.forWord(_word);
  late var _check = FormRecallCheck(
    expectedForm: _prompt.expectedForm,
    forms: _word.forms,
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: FormRecallView(
      check: _check,
      explanation: _prompt.explanation,
      sentenceBefore: _prompt.before,
      sentenceAfter: _prompt.after,
      syllableCount: _word.syllables.length,
      onSubmit: (text) => setState(() => _check = _check.submit(text)),
      onHint: () => setState(() => _check = _check.takeHint()),
      onContinue: () {},
    ),
  );
}

void main() {
  Future<void> pumpRecall(WidgetTester tester) =>
      tester.pumpFlui(const _RecallHost(), surfaceSize: const Size(400, 1200));

  testWidgets('two hints (syllables, first letter), then the reveal', (
    tester,
  ) async {
    await pumpRecall(tester);
    expect(find.text('Ahora dilo tú.'), findsOneWidget);

    await tester.tap(find.text('Pista'));
    await tester.pump();
    expect(find.text('Tiene 3 sílabas.'), findsOneWidget);

    await tester.tap(find.text('Pista'));
    await tester.pump();
    expect(find.text('Tiene 3 sílabas. Empieza por «p».'), findsOneWidget);

    await tester.tap(find.text('Ver la palabra'));
    await tester.pump();
    expect(
      find.text('La palabra es «perspicaz». La tendrás de nuevo pronto.'),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('a wrong answer says "Casi." and gives the first hint', (
    tester,
  ) async {
    await pumpRecall(tester);

    await tester.enterText(find.byType(TextField), 'listo');
    await tester.tap(find.text('Comprobar'));
    await tester.pump();

    expect(find.text('Casi. Prueba otra vez.'), findsOneWidget);
    expect(find.text('Tiene 3 sílabas.'), findsOneWidget);
  });

  testWidgets('accepts accents, case and one typo', (tester) async {
    await pumpRecall(tester);

    await tester.enterText(fluiField('Tu palabra'), 'PERSPÍKAZ');
    await tester.tap(find.text('Comprobar'));
    await tester.pump();

    expect(find.text('¡Eso es!'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });
}
