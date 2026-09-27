/// The closed catalog of behaviors a training/diagnosis challenge or
/// attempt can surface.
///
/// Mirrors `app/lib/features/training/domain/behavior_code.dart` (not
/// imported: `content/` is a pure-Dart package independent of `app/`).
/// Closed and three-way-parity checked: this catalog,
/// `app/lib/features/training/domain/behavior_code.dart`, and
/// `supabase/functions/speech-analyze/behavior_codes.json` (the wire-format
/// source of truth) all share the same [BehaviorCode.wireCode] set, in the
/// same order — see `test/model/behavior_catalog_parity_test.dart`.
library;

import 'package:content/src/model/challenge.dart' show Skill;

enum Polarity { strength, opportunity }

/// Thinking and language are AI-observed; voice and fluency are always
/// client-measured, never judged by the LLM (design D12).
enum BehaviorArea {
  thinking,
  language,
  voice,
  fluency;

  /// The [Skill] this area is scored under. `fluency.skill == voice`: a
  /// challenge only declares `skill: voice`, never `skill: fluency`.
  Skill get skill =>
      this == BehaviorArea.fluency ? Skill.voice : Skill.values.byName(name);
}

enum BehaviorCode {
  // Thinking — AI-observed.
  mainPointLate(BehaviorArea.thinking, Polarity.opportunity, 'main_point_late'),
  noClearStructure(
    BehaviorArea.thinking,
    Polarity.opportunity,
    'no_clear_structure',
  ),
  missingExample(
    BehaviorArea.thinking,
    Polarity.opportunity,
    'missing_example',
  ),
  noClosing(BehaviorArea.thinking, Polarity.opportunity, 'no_closing'),
  clearMainPoint(BehaviorArea.thinking, Polarity.strength, 'clear_main_point'),
  orderedIdeas(BehaviorArea.thinking, Polarity.strength, 'ordered_ideas'),

  // Language — AI-observed.
  vagueWord(BehaviorArea.language, Polarity.opportunity, 'vague_word'),
  repeatedWord(BehaviorArea.language, Polarity.opportunity, 'repeated_word'),
  weakConnector(BehaviorArea.language, Polarity.opportunity, 'weak_connector'),
  registerMismatch(
    BehaviorArea.language,
    Polarity.opportunity,
    'register_mismatch',
  ),
  preciseWord(BehaviorArea.language, Polarity.strength, 'precise_word'),
  variedVocabulary(
    BehaviorArea.language,
    Polarity.strength,
    'varied_vocabulary',
  ),

  // Voice / Fluency — client-measured, never AI-judged.
  paceFast(BehaviorArea.voice, Polarity.opportunity, 'pace_fast'),
  paceSlow(BehaviorArea.voice, Polarity.opportunity, 'pace_slow'),
  longPauses(BehaviorArea.fluency, Polarity.opportunity, 'long_pauses'),
  fillerHeavy(BehaviorArea.fluency, Polarity.opportunity, 'filler_heavy'),
  volumeUnstable(BehaviorArea.voice, Polarity.opportunity, 'volume_unstable'),
  steadyPace(BehaviorArea.voice, Polarity.strength, 'steady_pace'),
  controlledFillers(
    BehaviorArea.fluency,
    Polarity.strength,
    'controlled_fillers',
  ),
  steadyVolume(BehaviorArea.voice, Polarity.strength, 'steady_volume'),
  usefulPauses(BehaviorArea.fluency, Polarity.strength, 'useful_pauses');

  const BehaviorCode(this.area, this.polarity, this.wireCode);

  final BehaviorArea area;
  final Polarity polarity;

  /// The snake_case identifier shared with the wire catalog and the app.
  final String wireCode;

  /// The catalog entry for [wireCode], or `null` when it is not a known
  /// (or has become a retired) code.
  static BehaviorCode? fromWireCode(String wireCode) {
    for (final code in BehaviorCode.values) {
      if (code.wireCode == wireCode) return code;
    }
    return null;
  }
}
