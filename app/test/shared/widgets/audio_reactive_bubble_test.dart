import 'dart:async';

import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/shared/widgets/audio_reactive_bubble.dart';
import 'package:flui/shared/widgets/organic_blob.dart';
import 'package:flui/shared/widgets/speaking_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: widget!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

double _amplitude(WidgetTester tester) =>
    tester.widget<SpeakingBubble>(find.byType(SpeakingBubble)).amplitude;

void main() {
  testWidgets('with no stream, amplitude stays at rest', (tester) async {
    await _pump(tester, const AudioReactiveBubble(state: BubbleState.idle));
    expect(_amplitude(tester), equals(0));
  });

  testWidgets('feeds recorder samples through the pipeline into the bubble', (
    tester,
  ) async {
    final controller = StreamController<double>();
    addTearDown(controller.close);
    await _pump(
      tester,
      AudioReactiveBubble(
        state: BubbleState.recording,
        amplitudeStream: controller.stream,
      ),
    );

    controller.add(0); // loud
    await tester.pump(); // flush the stream's microtask-scheduled event
    await tester.pump(); // first animated frame
    // First frame after a loud sample must not jump straight to 1.0 — the
    // pipeline smooths, and the interpolation controller eases in too.
    final firstFrame = _amplitude(tester);
    expect(firstFrame, greaterThanOrEqualTo(0));
    expect(firstFrame, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 60));
    final midFrame = _amplitude(tester);
    expect(midFrame, greaterThanOrEqualTo(firstFrame));

    await tester.pump(const Duration(milliseconds: 120));
    final laterFrame = _amplitude(tester);
    expect(laterFrame, greaterThanOrEqualTo(midFrame));
  });

  testWidgets('under reduced motion, samples still drive amplitude (stepped)', (
    tester,
  ) async {
    final controller = StreamController<double>();
    addTearDown(controller.close);
    await _pump(
      tester,
      AudioReactiveBubble(
        state: BubbleState.recording,
        amplitudeStream: controller.stream,
      ),
      disableAnimations: true,
    );

    controller.add(0);
    await tester.pump(); // flush the stream's microtask-scheduled event
    await tester.pump();
    expect(_amplitude(tester), greaterThan(0));
  });

  testWidgets('passes through state, size, onTap, recordingSeconds, onStop', (
    tester,
  ) async {
    var tapped = false;
    var stopped = false;
    await _pump(
      tester,
      AudioReactiveBubble(
        state: BubbleState.recording,
        size: 210,
        onTap: () => tapped = true,
        recordingSeconds: 7,
        onStop: () => stopped = true,
      ),
    );
    final bubble = tester.widget<SpeakingBubble>(find.byType(SpeakingBubble));
    expect(bubble.size, equals(210));
    expect(bubble.recordingSeconds, equals(7));

    bubble.onStop!();
    expect(stopped, isTrue);
    bubble.onTap!();
    expect(tapped, isTrue);
  });

  testWidgets('renders an OrganicBlob (delegates to SpeakingBubble)', (
    tester,
  ) async {
    await _pump(tester, const AudioReactiveBubble(state: BubbleState.idle));
    expect(find.byType(OrganicBlob), findsOneWidget);
  });
}
