import 'dart:async';
import 'dart:math' as math;

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
import 'package:flui/features/speaking/presentation/widgets/voice_orb.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum _Phase { ready, recording, analyzing, feedback, comparison, denied, error }

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
  StreamSubscription<double>? _amplitudeSubscription;
  int _secondsLeft = 45;
  int _attempt = 1;
  double _amplitude = -60;
  DateTime? _startedAt;
  late SpeakingMetrics _firstMetrics;
  late SpeakingMetrics _currentMetrics;
  late SpeakingFeedback _feedback;
  late SpeechTranscript _currentTranscript;

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_amplitudeSubscription?.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      setState(() => _phase = _Phase.ready);
      if (!await _recorder.requestPermission()) {
        if (mounted) setState(() => _phase = _Phase.denied);
        return;
      }
      await _recorder.start();
      _startedAt = DateTime.now();
      _secondsLeft = 45;
      _amplitudeSubscription = _recorder.amplitude.listen((value) {
        if (mounted) setState(() => _amplitude = value);
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          unawaited(_finish());
        } else {
          setState(() => _secondsLeft--);
        }
      });
      if (mounted) setState(() => _phase = _Phase.recording);
    } on Object catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    if (mounted) setState(() => _phase = _Phase.analyzing);
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
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  _Phase.ready => _ReadyView(onStart: _start),
                  _Phase.recording => _RecordingView(
                    secondsLeft: _secondsLeft,
                    amplitude: _amplitude,
                    onFinish: _finish,
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
                    onAction: _start,
                  ),
                  _Phase.error => _RecoveryView(
                    icon: LucideIcons.rotate_ccw,
                    title: 'No pudimos analizar este intento',
                    message:
                        'Tu audio no se guardó. Puedes grabarlo otra vez '
                        'ahora mismo.',
                    action: 'Grabar de nuevo',
                    onAction: _start,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const new({required this.onStart});
  final VoidCallback onStart;

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
      Semantics(
        button: true,
        label: 'Empezar grabación de voz',
        child: _MicButton(onTap: onStart),
      ),
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

class _RecordingView extends StatelessWidget {
  const new({
    required this.secondsLeft,
    required this.amplitude,
    required this.onFinish,
  });
  final int secondsLeft;
  final double amplitude;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final level = ((amplitude + 60) / 60).clamp(0.08, 1.0);
    return Column(
      key: const ValueKey('recording'),
      children: [
        const FluiLabel('TE ESCUCHO'),
        const SizedBox(height: 28),
        Text('$secondsLeft', style: Theme.of(context).textTheme.displayLarge),
        const Text('segundos restantes'),
        const SizedBox(height: 42),
        VoiceOrb(
          state: VoiceOrbState.recording,
          amplitude: level,
          semanticLabel: 'Flui está escuchando tu voz',
        ),
        const SizedBox(height: 24),
        const SpeakerCueCards(),
        const SizedBox(height: 28),
        FluiButton.primary(label: 'Terminar intento', onPressed: onFinish),
      ],
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  const new();
  @override
  Widget build(BuildContext context) => const Column(
    key: ValueKey('analyzing'),
    children: [
      SizedBox(height: 80),
      CircularProgressIndicator(color: FluiColors.greenSecondary),
      SizedBox(height: 24),
      Text('Escuchando tu ritmo…', style: TextStyle(fontSize: 22)),
      SizedBox(height: 8),
      Text('Buscamos pausas y patrones útiles, no una nota perfecta.'),
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
  const new({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      children: [
        VoiceOrb(
          state: VoiceOrbState.listening,
          amplitude: .2,
          semanticLabel: 'Empezar grabación',
          onTap: onTap,
        ),
        const SizedBox(height: 8),
        const Text(
          'Empezar a hablar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 4),
        const Text(
          'Toca la esfera cuando estés listo',
          style: TextStyle(color: FluiColors.gray),
        ),
      ],
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
