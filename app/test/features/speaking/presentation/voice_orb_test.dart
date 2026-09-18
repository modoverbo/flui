import 'package:flui/features/speaking/presentation/widgets/voice_orb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('voice orb exposes its state and reacts to amplitude', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceOrb(
            state: VoiceOrbState.recording,
            amplitude: .8,
            semanticLabel: 'Grabando tu voz',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Grabando tu voz'), findsOneWidget);
    final orb = tester.widget<CustomPaint>(find.byType(CustomPaint).last);
    expect(orb.size.width, greaterThanOrEqualTo(176));
  });

  testWidgets('voice orb is static when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: VoiceOrb(
            state: VoiceOrbState.listening,
            amplitude: .4,
            semanticLabel: 'Lista para hablar',
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(VoiceOrb),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });
}
