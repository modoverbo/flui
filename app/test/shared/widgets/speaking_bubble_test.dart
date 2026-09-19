import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/shared/widgets/organic_blob.dart';
import 'package:flui/shared/widgets/speaking_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('es'));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool disableAnimations = false,
  Size surfaceSize = const Size(400, 800),
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
          size: surfaceSize,
        ),
        child: widget!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

OrganicBlob _blob(WidgetTester tester) =>
    tester.widget<OrganicBlob>(find.byType(OrganicBlob));

void main() {
  group('SpeakingBubble states are visually distinct', () {
    testWidgets('idle: gentle breathing loop, calm colors, no wobble', (
      tester,
    ) async {
      await _pump(tester, const SpeakingBubble(state: BubbleState.idle));
      expect(_blob(tester).wobble, equals(0));
      expect(
        find.descendant(
          of: find.byType(SpeakingBubble),
          matching: find.byType(AnimatedBuilder),
        ),
        findsWidgets,
      );
    });

    testWidgets('ready: bigger breath invite + is tappable', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        SpeakingBubble(state: BubbleState.ready, onTap: () => tapped = true),
      );
      expect(find.bySemanticsLabel(_l10n.bubbleStateReady), findsOneWidget);
      await tester.tap(find.byType(SpeakingBubble));
      expect(tapped, isTrue);
    });

    testWidgets('recording: amplitude drives scale and wobble', (tester) async {
      await _pump(tester, const SpeakingBubble(state: BubbleState.recording));
      final low = _blob(tester).scale;
      expect(low, closeTo(1.02, 0.005));

      await _pump(
        tester,
        const SpeakingBubble(state: BubbleState.recording, amplitude: 1),
      );
      final high = _blob(tester).scale;
      expect(high, closeTo(1.15, 0.005));
      expect(high, greaterThan(low));
      expect(_blob(tester).wobble, equals(1.0));
    });

    testWidgets('recording: colors differ from idle', (tester) async {
      await _pump(tester, const SpeakingBubble(state: BubbleState.idle));
      final idleColors = _blob(tester).colors;
      await _pump(
        tester,
        const SpeakingBubble(state: BubbleState.recording, amplitude: 0.5),
      );
      final recordingColors = _blob(tester).colors;
      expect(recordingColors, isNot(equals(idleColors)));
    });

    testWidgets('processing: contracted below idle rest scale, not a spinner', (
      tester,
    ) async {
      await _pump(tester, const SpeakingBubble(state: BubbleState.idle));
      await tester.pump(const Duration(milliseconds: 50));
      final idleScale = _blob(tester).scale;

      await _pump(tester, const SpeakingBubble(state: BubbleState.processing));
      await tester.pump(const Duration(milliseconds: 50));
      final processingScale = _blob(tester).scale;

      expect(processingScale, lessThan(idleScale));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('result: settles to a resting pulse then holds, no loop', (
      tester,
    ) async {
      await _pump(tester, const SpeakingBubble(state: BubbleState.result));
      await tester.pump(const Duration(milliseconds: 500));
      final settled = _blob(tester).scale;
      await tester.pump(const Duration(seconds: 2));
      final stillSettled = _blob(tester).scale;
      expect(stillSettled, equals(settled));
      expect(settled, closeTo(1.0, 0.02));
    });

    testWidgets('error: uses the amber palette, never red', (tester) async {
      await _pump(tester, const SpeakingBubble(state: BubbleState.error));
      final colors = _blob(tester).colors;
      expect(colors, isNot(contains(const Color(0xFFFF0000))));
      expect(find.bySemanticsLabel(_l10n.bubbleStateError), findsOneWidget);
    });
  });

  group('Reduced motion', () {
    testWidgets(
      'idle renders a fixed rest scale with no animated builder loop',
      (tester) async {
        await _pump(
          tester,
          const SpeakingBubble(state: BubbleState.idle),
          disableAnimations: true,
        );
        expect(_blob(tester).scale, equals(1.0));
      },
    );

    testWidgets('states remain visually distinguishable under reduced motion', (
      tester,
    ) async {
      await _pump(
        tester,
        const SpeakingBubble(state: BubbleState.processing),
        disableAnimations: true,
      );
      final processingScale = _blob(tester).scale;

      await _pump(
        tester,
        const SpeakingBubble(state: BubbleState.idle),
        disableAnimations: true,
      );
      final idleScale = _blob(tester).scale;

      expect(processingScale, isNot(equals(idleScale)));
    });

    testWidgets('recording amplitude reactivity is not disabled outright', (
      tester,
    ) async {
      await _pump(
        tester,
        const SpeakingBubble(state: BubbleState.recording, amplitude: 1),
        disableAnimations: true,
      );
      expect(_blob(tester).scale, greaterThan(1.0));
    });
  });

  group('Semantics and state announcements', () {
    testWidgets('announces each state distinctly', (tester) async {
      for (final entry in {
        BubbleState.idle: _l10n.bubbleStateIdle,
        BubbleState.recording: _l10n.bubbleStateRecording,
        BubbleState.processing: _l10n.bubbleStateProcessing,
        BubbleState.result: _l10n.bubbleStateResult,
        BubbleState.error: _l10n.bubbleStateError,
      }.entries) {
        await _pump(tester, SpeakingBubble(state: entry.key));
        expect(
          find.bySemanticsLabel(entry.value),
          findsOneWidget,
          reason: 'state ${entry.key}',
        );
      }
    });
  });

  group('Recording timer and stop affordance', () {
    testWidgets('shows a visible timer while recording', (tester) async {
      await _pump(
        tester,
        const SpeakingBubble(
          state: BubbleState.recording,
          recordingSeconds: 12,
        ),
      );
      expect(find.textContaining('12'), findsOneWidget);
    });

    testWidgets('offers an obvious stop control while recording', (
      tester,
    ) async {
      var stopped = false;
      await _pump(
        tester,
        SpeakingBubble(
          state: BubbleState.recording,
          onStop: () => stopped = true,
        ),
      );
      expect(find.bySemanticsLabel(_l10n.bubbleStopRecording), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(_l10n.bubbleStopRecording));
      expect(stopped, isTrue);
    });

    testWidgets('no stop control outside the recording state', (tester) async {
      await _pump(
        tester,
        SpeakingBubble(state: BubbleState.idle, onStop: () {}),
      );
      expect(find.bySemanticsLabel(_l10n.bubbleStopRecording), findsNothing);
    });
  });

  group('Responsive across widths and text scale', () {
    testWidgets('renders without overflow at 360px width, textScale 1.3', (
      tester,
    ) async {
      await _pump(
        tester,
        const SpeakingBubble(state: BubbleState.recording, recordingSeconds: 5),
        surfaceSize: const Size(360, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at desktop width', (tester) async {
      await _pump(
        tester,
        const SpeakingBubble(state: BubbleState.ready),
        surfaceSize: const Size(1440, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Performance', () {
    testWidgets('is wrapped in a RepaintBoundary', (tester) async {
      await _pump(tester, const SpeakingBubble(state: BubbleState.idle));
      expect(
        find.descendant(
          of: find.byType(SpeakingBubble),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });
}
