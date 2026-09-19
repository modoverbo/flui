import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/onboarding/presentation/intro_page.dart';
import 'package:flui/features/onboarding/presentation/welcome_page.dart';
import 'package:flui/features/vocabulary/presentation/word_detail_page.dart';
import 'package:flui/features/vocabulary/presentation/words_page.dart';
import 'package:flui/shared/widgets/choice_chips.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/learning_builders.dart';
import '../helpers/learning_fakes.dart';
import '../helpers/pump_router.dart';
import '../helpers/reduce_motion.dart';

/// One screen under test, with everything it needs to build.
typedef Screen = ({String name, String location, Widget page});

void main() {
  late LearningFakes fakes;

  setUp(() async {
    fakes = LearningFakes();
    await fakes.progress.saveProgress(
      buildProgress(
        wordId: seedWord('perspicaz').id,
        introducedOn: day(1),
        nextDueOn: day(30),
      ),
    );
  });

  tearDown(() => fakes.dispose());

  List<Override> allOverrides() => fakes.overrides;

  List<Screen> screens() => [
    (name: 'welcome', location: AppRoutes.welcome, page: const WelcomePage()),
    (name: 'intro', location: AppRoutes.intro, page: const IntroPage()),
    (name: 'palabras', location: AppRoutes.words, page: const WordsPage()),
    (
      name: 'word detail',
      location: AppRoutes.wordDetail(seedWord('perspicaz').id),
      page: WordDetailPage(wordId: seedWord('perspicaz').id),
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester,
    Screen screen, {
    required Size size,
  }) async {
    reduceMotion(tester);
    await pumpRoutedPage(
      tester,
      location: screen.location,
      page: screen.page,
      overrides: allOverrides(),
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
  }

  group('text scaling', () {
    for (final screen in screens()) {
      testWidgets('${screen.name} survives 130 % type on a small phone', (
        tester,
      ) async {
        scaleText(tester, 1.3);
        await pumpScreen(tester, screen, size: const Size(360, 740));

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('touch targets', () {
    for (final screen in screens()) {
      testWidgets('${screen.name} has no target under 44 px', (tester) async {
        await pumpScreen(tester, screen, size: const Size(420, 1400));

        final targets = [
          ...find.byType(FilledButton).evaluate(),
          ...find.byType(OutlinedButton).evaluate(),
          ...find.byType(TextButton).evaluate(),
          ...find.byType(IconButton).evaluate(),
          ...find.byType(ChoiceChip).evaluate(),
          // Palabras' filter chips: an editorial `FluiChoiceChip`, never a
          // native `ChoiceChip` (`docs/redesign/01-design-system.md`).
          ...find.byType(FluiChoiceChip).evaluate(),
        ];
        expect(targets, isNotEmpty, reason: 'nothing to check');
        for (final element in targets) {
          final size = element.size!;
          if (size.isEmpty) continue;
          expect(
            size.height,
            greaterThanOrEqualTo(FluiSpacing.minTapTarget),
            reason: '${screen.name}: ${element.widget.runtimeType}',
          );
        }
      });
    }
  });

  group('semantics', () {
    testWidgets('the intro options announce their state and group', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, (
        name: 'intro',
        location: AppRoutes.intro,
        page: const IntroPage(),
      ), size: const Size(420, 1400));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Seguir'));
        await tester.pumpAndSettle();
      }

      expect(
        tester.getSemantics(find.bySemanticsLabel('Trabajo')),
        isSemantics(label: 'Trabajo', isButton: true, isSelected: false),
      );
      await tester.tap(find.text('Trabajo'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Trabajo')),
        isSemantics(label: 'Trabajo', isButton: true, isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('the mastery meter is read as one progress statement', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, (
        name: 'word detail',
        location: AppRoutes.wordDetail(seedWord('perspicaz').id),
        page: WordDetailPage(wordId: seedWord('perspicaz').id),
      ), size: const Size(420, 3200));

      expect(
        find.bySemanticsLabel(
          RegExp(r'^El camino de esta palabra: \d de 5\. descubierta'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('labels are announced in sentence case, not shouted', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, (
        name: 'palabras',
        location: AppRoutes.words,
        page: const WordsPage(),
      ), size: const Size(420, 1400));

      // Rendered "NUEVA"/"PRACTICA"/"TUYA", announced as written.
      expect(find.bySemanticsLabel('Practica'), findsWidgets);
      semantics.dispose();
    });
  });
}
