import 'package:flui/features/vocabulary/domain/exercises/cloze_attempt_flow.dart';
import 'package:flui/features/vocabulary/presentation/widgets/cloze_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/learning_fakes.dart';
import '../../../helpers/pump_app.dart';

/// Holds the domain flow the way the session controller does.
class _ClozeHost extends StatefulWidget {
  const new({required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_ClozeHost> createState() => _ClozeHostState();
}

class _ClozeHostState extends State<_ClozeHost> {
  var _flow = ClozeAttemptFlow.start(seedWord('perspicaz').exercises.first);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: ClozeView(
      flow: _flow,
      onConfirm: (id) => setState(() => _flow = _flow.answer(id)),
      onRetry: () => setState(() => _flow = _flow.dismissFeedback()),
      onContinue: widget.onContinue,
    ),
  );
}

void main() {
  Future<List<String>> pumpCloze(WidgetTester tester) async {
    final continued = <String>[];
    await tester.pumpFlui(
      _ClozeHost(onContinue: () => continued.add('continue')),
      surfaceSize: const Size(400, 1200),
    );
    return continued;
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.text(option));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
  }

  testWidgets('first try: "¡Eso es!" with the explanation', (tester) async {
    final continued = await pumpCloze(tester);

    expect(find.text('Encuentra la palabra que encaja'), findsOneWidget);
    expect(find.text('suspicaz'), findsOneWidget);
    expect(find.text('perspicuo'), findsOneWidget);
    // Nothing chosen yet: "Confirmar" is disabled.
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(find.text('Casi.'), findsNothing);

    await choose(tester, 'perspicaz');

    expect(find.text('¡Eso es!'), findsOneWidget);
    expect(find.textContaining('El perspicaz ve'), findsOneWidget);
    expect(find.text('Por qué no las otras'), findsNothing);
    await tester.tap(find.text('Continuar'));
    expect(continued, ['continue']);
  });

  testWidgets('wrong → hint → specific hint → forced reveal with why-nots', (
    tester,
  ) async {
    await pumpCloze(tester);

    await choose(tester, 'suspicaz');
    expect(find.text('Casi.'), findsOneWidget);
    expect(find.text('Todavía no. Piensa otra vez.'), findsOneWidget);
    expect(
      find.text(
        'La palabra describe a alguien que capta rápido lo que no es evidente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Confirmar'), findsNothing);

    await tester.tap(find.text('Intentar de nuevo'));
    await tester.pump();
    expect(find.bySemanticsLabel('suspicaz, descartada'), findsOneWidget);

    await choose(tester, 'perspicuo');
    expect(find.text('Casi.'), findsOneWidget);
    expect(find.textContaining('¿Andrés es fácil de entender'), findsOneWidget);

    await tester.tap(find.text('Intentar de nuevo'));
    await tester.pump();
    expect(
      find.text('Solo queda una opción. Tócala para verla.'),
      findsOneWidget,
    );

    await choose(tester, 'perspicaz');
    expect(find.text('¡Ahí está!'), findsOneWidget);
    expect(find.text('POR QUÉ NO LAS OTRAS'), findsOneWidget);
    expect(find.textContaining('Andrés confía en su equipo.'), findsOneWidget);
    expect(find.textContaining('Andrés no explica: descubre.'), findsOneWidget);
  });

  testWidgets('second try is accepted after a hint', (tester) async {
    await pumpCloze(tester);

    await choose(tester, 'perspicuo');
    await tester.tap(find.text('Intentar de nuevo'));
    await tester.pump();
    await choose(tester, 'perspicaz');

    expect(find.text('¡Eso es!'), findsOneWidget);
  });
}
