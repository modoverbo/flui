import 'package:flui/app/router/app_routes.dart';
import 'package:flui/features/speaking/presentation/speaking_challenge_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_router.dart';
import '../../../helpers/reduce_motion.dart';

void main() {
  group('SpeakingTabPage', () {
    testWidgets("is Habla's landing: the ready view opens the exercise", (
      tester,
    ) async {
      reduceMotion(tester);
      await pumpRoutedPage(
        tester,
        location: AppRoutes.speakingChallenge,
        page: const SpeakingTabPage(),
        otherRoutes: [AppRoutes.speakingChallengeLive],
      );
      await tester.pumpAndSettle();

      expect(find.text('Abrir ejercicio'), findsOneWidget);
    });

    testWidgets('honours reduced motion: no looping animation is scheduled', (
      tester,
    ) async {
      reduceMotion(tester);
      await pumpRoutedPage(
        tester,
        location: AppRoutes.speakingChallenge,
        page: const SpeakingTabPage(),
      );
      await tester.pumpAndSettle();

      // The ready-state bubble breathes forever without reduced motion
      // (`SpeakingBubble._configureForState`); under reduced motion its
      // controllers are stopped, so no ticker keeps scheduling frames.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'renders without overflow at 1.3x text scale on a 360px phone',
      (tester) async {
        scaleText(tester, 1.3);
        reduceMotion(tester);
        await pumpRoutedPage(
          tester,
          location: AppRoutes.speakingChallenge,
          page: const SpeakingTabPage(),
          surfaceSize: const Size(360, 900),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
