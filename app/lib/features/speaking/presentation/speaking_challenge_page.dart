import 'dart:async';
import 'dart:math' as math;

import 'package:flui/app/router/app_routes.dart';
import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/speaking/data/record_speech_recorder.dart';
import 'package:flui/features/speaking/domain/speaking_feedback.dart';
import 'package:flui/features/speaking/domain/speaking_metrics.dart';
import 'package:flui/features/speaking/domain/speech_analysis_repository.dart';
import 'package:flui/features/speaking/domain/speech_analyzer.dart';
import 'package:flui/features/speaking/domain/speech_recorder.dart';
import 'package:flui/features/speaking/domain/speech_transcript.dart';
import 'package:flui/features/speaking/presentation/providers/speaking_providers.dart';
import 'package:flui/features/speaking/presentation/widgets/speaker_cue_cards.dart';
import 'package:flui/shared/widgets/audio_reactive_bubble.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flui/shared/widgets/speaking_bubble.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

enum _Phase {
  ready,
  permission,
  recording,
  analyzing,
  feedback,
  comparison,
  denied,
  error,
}

/// Habla's tab landing: a prompt, timer pill, and navigation CTA. The
/// microphone stays on the full-screen challenge so selecting the tab never
/// begins capture (`docs/redesign/02-navigation-model.md` Decision A).
/// Opening a challenge goes to [AppRoutes.speakingChallengeLive] — the
/// [SpeakingChallengePage] state machine — which takes over the full screen
/// on the root navigator, the same nested-under-a-branch pattern
/// `/today/time` already uses (`context.go`, not `context.push`: a pushed
/// location isn't resolved against a `parentNavigatorKey` route the same
/// way a full `go` is). See `app_router.dart`.
class SpeakingTabPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FluiColors.cream,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: const Text('Entrenamiento oral'),
      centerTitle: true,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
            child: _ReadyView(
              navigationOnly: true,
              onStart: (_) => context.go(AppRoutes.speakingChallengeLive),
            ),
          ),
        ),
      ),
    ),
  );
}

class SpeakingChallengePage extends ConsumerStatefulWidget {
  const new({this.recorder, this.analysisRepository, super.key});

  final SpeechRecorder? recorder;
  final SpeechAnalysisRepository? analysisRepository;

  @override
  ConsumerState<SpeakingChallengePage> createState() =>
      _SpeakingChallengePageState();
}

class _SpeakingChallengePageState extends ConsumerState<SpeakingChallengePage> {
  late final SpeechRecorder _recorder =
      widget.recorder ?? RecordSpeechRecorder();
  late final SpeechAnalysisRepository _analysisRepository =
      widget.analysisRepository ?? ref.read(speechAnalysisRepositoryProvider);
  static const _analyzer = SpeechAnalyzer();
  _Phase _phase = _Phase.ready;
  Timer? _timer;
  bool _holdRequested = false;
  bool _recorderActive = false;
  bool _startPending = false;
  bool _cancellationPending = false;
  Future<void>? _cancelFuture;
  int _holdGeneration = 0;
  int? _activePointer;
  // Created once and reused across rebuilds: `_recorder.amplitude` is a
  // getter that builds a fresh `Stream` on every access, and
  // `AudioReactiveBubble` resubscribes (resetting its smoothing pipeline)
  // whenever the stream instance it's given changes identity.
  late final Stream<double> _amplitudeStream = _recorder.amplitude;
  int _secondsLeft = 45;
  int _attempt = 1;
  DateTime? _recordingStartedAt;
  DateTime? _startedAt;
  late SpeakingMetrics _firstMetrics;
  late SpeakingMetrics _currentMetrics;
  late SpeakingFeedback _feedback;
  late SpeechTranscript _currentTranscript;

  @override
  void dispose() {
    _timer?.cancel();
    if (_holdRequested || _recorderActive || _cancelFuture != null) {
      unawaited(_cancelAndDisposeRecorder());
    } else {
      unawaited(_recorder.dispose());
    }
    super.dispose();
  }

  void _pressMicrophone(int? pointer) {
    if (_phase != _Phase.ready ||
        _holdRequested ||
        _startPending ||
        _cancellationPending) {
      return;
    }
    _activePointer = pointer;
    _holdRequested = true;
    _cancelFuture = null;
    _startPending = true;
    unawaited(_startHold(++_holdGeneration));
  }

  Future<void> _startHold(int generation) async {
    try {
      if (mounted) setState(() => _phase = _Phase.permission);
      final permitted = await _recorder.requestPermission();
      if (!mounted || !_holdRequested || generation != _holdGeneration) return;
      if (!permitted) {
        _holdRequested = false;
        _activePointer = null;
        setState(() => _phase = _Phase.denied);
        return;
      }
      await _recorder.start();
      if (!mounted || !_holdRequested || generation != _holdGeneration) {
        await _cancelRecorder();
        return;
      }
      _recorderActive = true;
      _recordingStartedAt = DateTime.now();
      _startedAt = _recordingStartedAt;
      _secondsLeft = 45;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          _holdRequested = false;
          _activePointer = null;
          unawaited(_submitRecording());
        } else {
          setState(() => _secondsLeft--);
        }
      });
      setState(() => _phase = _Phase.recording);
    } on Object catch (_) {
      if (generation == _holdGeneration && _holdRequested) {
        _holdRequested = false;
        _activePointer = null;
        if (mounted) setState(() => _phase = _Phase.error);
      }
    } finally {
      _startPending = false;
    }
  }

  void _releaseMicrophone(int? pointer) {
    if (!_holdRequested || (pointer != null && pointer != _activePointer)) {
      return;
    }
    _holdRequested = false;
    _holdGeneration++;
    _activePointer = null;
    if (_phase == _Phase.permission) {
      if (mounted) setState(() => _phase = _Phase.ready);
      return;
    }
    if (_phase != _Phase.recording) return;
    final elapsed = DateTime.now().difference(
      _recordingStartedAt ?? DateTime.now(),
    );
    if (elapsed < const Duration(milliseconds: 600)) {
      _timer?.cancel();
      unawaited(_cancelRecorder());
      if (mounted) setState(() => _phase = _Phase.ready);
      return;
    }
    unawaited(_submitRecording());
  }

  void _cancelMicrophone(int? pointer) {
    if (!_holdRequested || (pointer != null && pointer != _activePointer)) {
      return;
    }
    _holdRequested = false;
    _holdGeneration++;
    _activePointer = null;
    _timer?.cancel();
    if (_phase == _Phase.recording || _phase == _Phase.permission) {
      unawaited(_cancelRecorder());
      if (mounted) setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _cancelRecorder() {
    final inFlight = _cancelFuture;
    if (inFlight != null) return inFlight;
    _cancellationPending = true;
    _recorderActive = false;
    final cancellation = _cancelAndCaptureFailure();
    _cancelFuture = cancellation;
    return cancellation;
  }

  Future<void> _cancelAndCaptureFailure() async {
    try {
      await _recorder.cancel();
    } on Object catch (_) {
      // Cancellation is a best-effort discard; disposal still releases the
      // recorder even if the platform plugin has already stopped it.
    } finally {
      _cancellationPending = false;
    }
  }

  Future<void> _cancelAndDisposeRecorder() async {
    if (_holdRequested || _recorderActive) await _cancelRecorder();
    if (_cancelFuture case final cancellation?) await cancellation;
    await _recorder.dispose();
  }

  Future<void> _submitRecording() async {
    if (_phase != _Phase.recording || !_recorderActive) return;
    _timer?.cancel();
    _recorderActive = false;
    setState(() => _phase = _Phase.analyzing);
    try {
      final bytes = await _recorder.stop();
      if (bytes.isEmpty) throw StateError('empty recording');
      final elapsed = DateTime.now().difference(_startedAt ?? DateTime.now());
      final duration = Duration(
        milliseconds: math.max(500, elapsed.inMilliseconds),
      );
      final result = await _analysisRepository.analyze(
        bytes,
        mimeType: 'audio/wav',
        duration: duration,
      );
      final transcript = result.valueOrNull;
      if (transcript == null || transcript.text.trim().isEmpty) {
        throw StateError('speech analysis failed');
      }
      final metrics = _analyzer.analyze(transcript);
      _currentTranscript = transcript;
      _currentMetrics = metrics;
      final measuredFeedback = _analyzer.feedback(metrics);
      _feedback = transcript.coaching == null
          ? measuredFeedback
          : SpeakingFeedback(
              signals: measuredFeedback.signals,
              retryCue: transcript.coaching!.retryCue,
            );
      if (_attempt == 1) _firstMetrics = metrics;
      if (!mounted) return;
      setState(() {
        _phase = _attempt == 1 ? _Phase.feedback : _Phase.comparison;
      });
    } on Object catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _retry() async {
    _attempt = 2;
    setState(() => _phase = _Phase.ready);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (event) => _releaseMicrophone(event.pointer),
      onPointerCancel: (event) => _cancelMicrophone(event.pointer),
      child: Scaffold(
        backgroundColor: FluiColors.cream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text('Entrenamiento oral'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: switch (_phase) {
                    _Phase.ready => _ReadyView(onStart: _pressMicrophone),
                    _Phase.permission => const _PermissionView(),
                    _Phase.recording => _RecordingView(
                      secondsLeft: _secondsLeft,
                      amplitudeStream: _amplitudeStream,
                      onFinish: () => _releaseMicrophone(null),
                    ),
                    _Phase.analyzing => const _AnalyzingView(),
                    _Phase.feedback => _FeedbackView(
                      feedback: _feedback,
                      transcript: _currentTranscript,
                      onRetry: _retry,
                    ),
                    _Phase.comparison => _ComparisonView(
                      before: _firstMetrics,
                      after: _currentMetrics,
                    ),
                    _Phase.denied => _RecoveryView(
                      icon: LucideIcons.mic_off,
                      title: 'Necesitamos acceso al micrófono',
                      message:
                          'Actívalo en los permisos del navegador y vuelve a '
                          'intentarlo.',
                      action: 'Intentar de nuevo',
                      onAction: () => setState(() => _phase = _Phase.ready),
                    ),
                    _Phase.error => _RecoveryView(
                      icon: LucideIcons.rotate_ccw,
                      title: 'No pudimos analizar este intento',
                      message:
                          'Tu audio no se guardó. Puedes grabarlo otra vez '
                          'ahora mismo.',
                      action: 'Grabar de nuevo',
                      onAction: () => setState(() => _phase = _Phase.ready),
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const new({required this.onStart, this.navigationOnly = false});
  final void Function(int?) onStart;
  final bool navigationOnly;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('ready'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FluiLabel('PAUSA DE PODER'),
      const SizedBox(height: FluiSpacing.sm),
      Text(
        'Cuéntame una decisión pequeña que mejoró tu día.',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, color: FluiColors.charcoal),
      ),
      const SizedBox(height: FluiSpacing.md),
      const Text(
        'Habla con naturalidad. Busca una idea clara y haz una pausa antes '
        'de tu conclusión.',
      ),
      const SizedBox(height: FluiSpacing.xl),
      const _TimePill(label: '45 s'),
      const SizedBox(height: FluiSpacing.xl),
      if (navigationOnly)
        FluiButton.primary(
          label: 'Abrir ejercicio',
          onPressed: () => onStart(null),
        )
      else
        _MicButton(onPress: onStart),
      const SizedBox(height: FluiSpacing.lg),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.shield_check, size: 16, color: FluiColors.gray),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Procesamos este intento y no guardamos tu audio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FluiColors.gray),
            ),
          ),
        ],
      ),
    ],
  );
}

class _PermissionView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('permission'),
    children: [
      const SizedBox(height: 48),
      const AudioReactiveBubble(state: BubbleState.processing),
      const SizedBox(height: 24),
      Semantics(
        liveRegion: true,
        label: 'Preparando el micrófono',
        child: const Text('Preparando el micrófono…'),
      ),
    ],
  );
}

class _RecordingView extends StatelessWidget {
  const new({
    required this.secondsLeft,
    required this.amplitudeStream,
    required this.onFinish,
  });
  final int secondsLeft;
  final Stream<double> amplitudeStream;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('recording'),
    children: [
      Semantics(
        liveRegion: true,
        label: 'Grabando. Mantén pulsado y suelta para analizar.',
        child: const FluiLabel('TE ESCUCHO'),
      ),
      const SizedBox(height: 28),
      Text('$secondsLeft', style: Theme.of(context).textTheme.displayLarge),
      const Text('segundos restantes'),
      const SizedBox(height: 42),
      AudioReactiveBubble(
        state: BubbleState.recording,
        amplitudeStream: amplitudeStream,
      ),
      const SizedBox(height: 24),
      const SpeakerCueCards(),
      const SizedBox(height: 28),
      Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            onFinish();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          button: true,
          label: 'Terminar intento y analizar',
          hint: 'Detiene la grabación para recibir comentarios escritos.',
          onTap: onFinish,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Suelta para detener y analizar'),
          ),
        ),
      ),
    ],
  );
}

class _AnalyzingView extends StatelessWidget {
  const new();
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('analyzing'),
    children: [
      const SizedBox(height: 56),
      const AudioReactiveBubble(state: BubbleState.processing),
      const SizedBox(height: 24),
      Semantics(
        liveRegion: true,
        label: 'Analizando tu voz',
        child: const Text(
          'Escuchando tu ritmo…',
          style: TextStyle(fontSize: 22),
        ),
      ),
      const SizedBox(height: 8),
      const Text('Buscamos pausas y patrones útiles, no una nota perfecta.'),
    ],
  );
}

class _FeedbackView extends StatelessWidget {
  const new({
    required this.feedback,
    required this.transcript,
    required this.onRetry,
  });
  final SpeakingFeedback feedback;
  final SpeechTranscript transcript;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('feedback'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FluiLabel('PRIMER INTENTO'),
      const SizedBox(height: 8),
      Text(
        'Ya tienes una base.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 24),
      if (transcript.coaching case final coaching?) ...[
        const FluiLabel('LO QUE ENTENDÍ'),
        const SizedBox(height: 8),
        Text(coaching.summary),
        const SizedBox(height: 14),
        _InsightCard(
          label: 'ESTRUCTURA · ESTIMACIÓN',
          detail: coaching.structure,
        ),
        _InsightCard(
          label: 'VOCABULARIO · ESTIMACIÓN',
          detail: coaching.vocabulary,
        ),
        _InsightCard(label: 'FORTALEZA', detail: coaching.strength),
        const SizedBox(height: 14),
        const FluiLabel('TRANSCRIPCIÓN'),
        const SizedBox(height: 8),
        Text(
          '“${transcript.text}”',
          style: const TextStyle(color: FluiColors.gray, height: 1.45),
        ),
        const SizedBox(height: 24),
      ],
      for (final signal in feedback.signals)
        _Signal(
          icon: switch (signal.title) {
            'Ritmo' => LucideIcons.gauge,
            'Muletillas' => LucideIcons.message_circle_more,
            'Pausas largas' => LucideIcons.pause,
            _ => LucideIcons.sparkles,
          },
          title: signal.title,
          detail: signal.detail,
        ),
      const SizedBox(height: 24),
      _CoachCue(cue: feedback.retryCue),
      const SizedBox(height: 24),
      FluiButton.primary(label: 'Inténtalo otra vez', onPressed: onRetry),
    ],
  );
}

class _InsightCard extends StatelessWidget {
  const new({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FluiColors.greenSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(detail),
      ],
    ),
  );
}

class _ComparisonView extends StatelessWidget {
  const new({required this.before, required this.after});
  final SpeakingMetrics before;
  final SpeakingMetrics after;

  @override
  Widget build(BuildContext context) {
    final fillerDelta = before.totalFillers - after.totalFillers;
    final improved = fillerDelta > 0;
    return Column(
      key: const ValueKey('comparison'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FluiLabel('ENTRENAMIENTO COMPLETADO'),
        const SizedBox(height: 8),
        Text(
          'Antes vs. ahora',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        _CompareRow(
          label: 'Muletillas',
          before: '${before.totalFillers}',
          after: '${after.totalFillers}',
          improvement: improved ? '−$fillerDelta' : 'Sigue entrenando',
        ),
        _CompareRow(
          label: 'Ritmo',
          before: before.wordsPerMinute?.toString() ?? '—',
          after: after.wordsPerMinute?.toString() ?? '—',
          improvement: _paceLabel(before.wordsPerMinute, after.wordsPerMinute),
        ),
        _CompareRow(
          label: 'Pausas largas',
          before: '${before.longPauses}',
          after: '${after.longPauses}',
          improvement: after.longPauses < before.longPauses
              ? 'Más control'
              : 'Observa el ritmo',
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FluiColors.greenSecondary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LO QUE CAMBIÓ',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                improved
                    ? 'Reduciste tus muletillas en el segundo intento.'
                    : 'Ya tienes una referencia real para tu próximo intento.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FluiButton.primary(
          label: 'Volver a Hoy',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String _paceLabel(int? before, int? after) {
    if (before == null || after == null) return 'Sin datos suficientes';
    return (after - 150).abs() < (before - 150).abs()
        ? 'Más control'
        : 'Observa el ritmo';
  }
}

class _MicButton extends StatelessWidget {
  const new({required this.onPress});
  final void Function(int?) onPress;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (event) => onPress(event.pointer),
    child: Semantics(
      button: true,
      label: 'Mantén pulsado para grabar',
      hint: 'Suelta para detener y analizar. Una pulsación breve se descarta.',
      onTap: () => onPress(null),
      child: const ExcludeSemantics(
        child: Column(
          children: [
            AudioReactiveBubble(state: BubbleState.ready),
            SizedBox(height: 8),
            Text(
              'Empezar a hablar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            SizedBox(height: 4),
            Text(
              'Mantén pulsado para grabar; suelta para analizar',
              style: TextStyle(color: FluiColors.gray),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimePill extends StatelessWidget {
  const new({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: FluiColors.yellowTint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class _Signal extends StatelessWidget {
  const new({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: FluiColors.greenSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(detail, style: const TextStyle(color: FluiColors.gray)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CoachCue extends StatelessWidget {
  const new({required this.cue});
  final String cue;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: FluiColors.yellowTint,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      'Tu reto: $cue',
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

class _CompareRow extends StatelessWidget {
  const new({
    required this.label,
    required this.before,
    required this.after,
    required this.improvement,
  });
  final String label;
  final String before;
  final String after;
  final String improvement;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$before → $after',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 10),
        Text(
          improvement,
          style: const TextStyle(
            color: FluiColors.greenSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _RecoveryView extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey(title),
    children: [
      const SizedBox(height: 48),
      Icon(icon, size: 56, color: FluiColors.greenSecondary),
      const SizedBox(height: 20),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 10),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      FluiButton.primary(label: action, onPressed: onAction),
    ],
  );
}
