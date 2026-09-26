import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/feedback.dart';
import 'package:flui/features/training/domain/observation.dart';
import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';

/// Composes [Feedback] from a set of observations: the primary opportunity
/// is the challenge's own skill area first, else any opportunity; a
/// strength is optional; the retry cue is the AI's own cue when given, else
/// a per-code template — never a number.
final class FeedbackComposer {
  const new();

  static const _retryCueTemplates = <BehaviorCode, String>{
    BehaviorCode.mainPointLate:
        'Abre con tu idea principal antes de justificarla.',
    BehaviorCode.noClearStructure:
        'Ordena tu respuesta en apertura, desarrollo y cierre.',
    BehaviorCode.missingExample:
        'Añade un ejemplo concreto que sostenga tu idea.',
    BehaviorCode.noClosing: 'Cierra con una frase que resuma tu punto.',
    BehaviorCode.vagueWord: 'Cambia la palabra vaga por una más precisa.',
    BehaviorCode.repeatedWord: 'Varía el vocabulario que ya usaste.',
    BehaviorCode.weakConnector: 'Usa un conector más claro entre tus ideas.',
    BehaviorCode.registerMismatch: 'Ajusta el registro a la situación.',
    BehaviorCode.paceFast: 'Repite hablando un poco más despacio.',
    BehaviorCode.paceSlow: 'Repite con un poco más de energía en el ritmo.',
    BehaviorCode.longPauses: 'Repite acortando tus pausas más largas.',
    BehaviorCode.fillerHeavy:
        'Repite haciendo una pausa silenciosa en vez de una muletilla.',
    BehaviorCode.volumeUnstable: 'Repite manteniendo un volumen más constante.',
  };

  static const _defaultRetryCue =
      'Repite prestando atención a tu punto principal.';

  Feedback compose({
    required List<Observation> observations,
    required SkillArea challengeArea,
    String? aiRetryCue,
  }) {
    final opportunities = observations
        .where((o) => o.polarity == Polarity.opportunity)
        .toList();
    final inArea = opportunities.where((o) => o.area == challengeArea);
    final primary = inArea.isNotEmpty
        ? inArea.first
        : (opportunities.isNotEmpty ? opportunities.first : null);
    final strengths = observations
        .where((o) => o.polarity == Polarity.strength)
        .toList();
    final strength = strengths.isNotEmpty ? strengths.first : null;
    return Feedback(
      primary: primary,
      strength: strength,
      retryCue: _retryCue(primary: primary, aiRetryCue: aiRetryCue),
    );
  }

  String _retryCue({required Observation? primary, String? aiRetryCue}) {
    if (aiRetryCue != null && aiRetryCue.trim().isNotEmpty) return aiRetryCue;
    if (primary == null) return _defaultRetryCue;
    return _retryCueTemplates[primary.code] ?? _defaultRetryCue;
  }
}
