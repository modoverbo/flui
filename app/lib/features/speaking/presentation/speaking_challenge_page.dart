import 'dart:async';

import 'package:flui/core/theme/flui_colors.dart';
import 'package:flui/core/theme/flui_spacing.dart';
import 'package:flui/features/speaking/data/record_speech_recorder.dart';
import 'package:flui/features/speaking/domain/speech_recorder.dart';
import 'package:flui/shared/widgets/flui_button.dart';
import 'package:flui/shared/widgets/flui_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

enum _Phase { ready, recording, analyzing, feedback, comparison, denied, error }

class SpeakingChallengePage extends StatefulWidget {
  const new({this._recorder, super.key});

  final SpeechRecorder? _recorder;

  @override
  State<SpeakingChallengePage> createState() => _SpeakingChallengePageState();
}

class _SpeakingChallengePageState extends State<SpeakingChallengePage> {
  late final SpeechRecorder _recorder =
      widget._recorder ?? RecordSpeechRecorder();
  _Phase _phase = _Phase.ready;
  Timer? _timer;
  StreamSubscription<double>? _amplitudeSubscription;
  int _secondsLeft = 45;
  int _attempt = 1;
  double _amplitude = -60;

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
                  _Phase.feedback => _FeedbackView(onRetry: _retry),
                  _Phase.comparison => const _ComparisonView(),
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
        SizedBox(
          height: 92,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(13, (index) {
              final wave = .25 + ((index % 5) / 5) * level;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 8,
                height: 76 * wave,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: FluiColors.greenSecondary,
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 42),
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
  const new({required this.onRetry});
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
      const _Signal(
        icon: LucideIcons.gauge,
        title: 'Ritmo',
        detail: '182 palabras/min · un poco rápido',
      ),
      const _Signal(
        icon: LucideIcons.message_circle_more,
        title: 'Muletillas',
        detail: '4 detectadas · estimación',
      ),
      const _Signal(
        icon: LucideIcons.pause,
        title: 'Pausa final',
        detail: 'Faltó aire antes de cerrar',
      ),
      const SizedBox(height: 24),
      const _CoachCue(),
      const SizedBox(height: 24),
      FluiButton.primary(label: 'Inténtalo otra vez', onPressed: onRetry),
    ],
  );
}

class _ComparisonView extends StatelessWidget {
  const new();
  @override
  Widget build(BuildContext context) => Column(
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
      const _CompareRow(
        label: 'Muletillas',
        before: '4',
        after: '1',
        improvement: '−75%',
      ),
      const _CompareRow(
        label: 'Ritmo',
        before: '182',
        after: '154',
        improvement: 'Más control',
      ),
      const _CompareRow(
        label: 'Pausa final',
        before: 'No',
        after: 'Sí',
        improvement: 'Logrado',
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FluiColors.greenSecondary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LO QUE CAMBIÓ',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Hiciste espacio para tu conclusión y sonaste más directo.',
              style: TextStyle(
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

class _MicButton extends StatelessWidget {
  const new({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(72),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Ink(
            width: 116,
            height: 116,
            decoration: const BoxDecoration(
              color: FluiColors.greenSecondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.mic, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 14),
          const Text(
            'Empezar a hablar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
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
  const new();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: FluiColors.yellowTint,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Text(
      'Tu reto: repite haciendo una pausa silenciosa antes de tu conclusión.',
      style: TextStyle(fontWeight: FontWeight.w700),
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
        Text(before, style: const TextStyle(color: FluiColors.gray)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(LucideIcons.arrow_right, size: 16),
        ),
        Text(after, style: const TextStyle(fontWeight: FontWeight.w800)),
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
