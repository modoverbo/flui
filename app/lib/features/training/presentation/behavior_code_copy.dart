import 'package:flui/core/l10n/gen/app_localizations.dart';
import 'package:flui/features/training/domain/behavior_code.dart';
import 'package:flui/features/training/domain/skill.dart';

/// The closed-catalog Spanish rendering of a [SkillArea], as a lowercase
/// noun phrase meant to sit inside a sentence (e.g. "Lo primero que vamos a
/// mejorar: {area}"). Shared by the diagnosis result page (U14a) and the
/// paywall's profile-echo copy (U14b) — both refer to the user's own
/// top-opportunity area without inventing a second phrasing for it.
String skillAreaLine(AppLocalizations l10n, SkillArea area) => switch (area) {
  SkillArea.thinking => l10n.diagnosisAreaThinking,
  SkillArea.language => l10n.diagnosisAreaLanguage,
  SkillArea.voice => l10n.diagnosisAreaVoice,
  SkillArea.fluency => l10n.diagnosisAreaFluency,
};

/// The closed-catalog Spanish rendering of an observed behavior — never a
/// number, never the raw wire code (spec `training-engine`: feedback is
/// expressed as observable behaviors). Shared by `TrainingLoopView` (U13b)
/// and the diagnosis result page (U14a) — both render the same closed
/// `BehaviorCode` catalog as sentences.
String behaviorCodeLine(AppLocalizations l10n, BehaviorCode code) =>
    switch (code) {
      BehaviorCode.mainPointLate => l10n.behaviorMainPointLate,
      BehaviorCode.noClearStructure => l10n.behaviorNoClearStructure,
      BehaviorCode.missingExample => l10n.behaviorMissingExample,
      BehaviorCode.noClosing => l10n.behaviorNoClosing,
      BehaviorCode.clearMainPoint => l10n.behaviorClearMainPoint,
      BehaviorCode.orderedIdeas => l10n.behaviorOrderedIdeas,
      BehaviorCode.vagueWord => l10n.behaviorVagueWord,
      BehaviorCode.repeatedWord => l10n.behaviorRepeatedWord,
      BehaviorCode.weakConnector => l10n.behaviorWeakConnector,
      BehaviorCode.registerMismatch => l10n.behaviorRegisterMismatch,
      BehaviorCode.preciseWord => l10n.behaviorPreciseWord,
      BehaviorCode.variedVocabulary => l10n.behaviorVariedVocabulary,
      BehaviorCode.paceFast => l10n.behaviorPaceFast,
      BehaviorCode.paceSlow => l10n.behaviorPaceSlow,
      BehaviorCode.longPauses => l10n.behaviorLongPauses,
      BehaviorCode.fillerHeavy => l10n.behaviorFillerHeavy,
      BehaviorCode.volumeUnstable => l10n.behaviorVolumeUnstable,
      BehaviorCode.steadyPace => l10n.behaviorSteadyPace,
      BehaviorCode.controlledFillers => l10n.behaviorControlledFillers,
      BehaviorCode.steadyVolume => l10n.behaviorSteadyVolume,
      BehaviorCode.usefulPauses => l10n.behaviorUsefulPauses,
    };
