import 'package:flui/features/training/domain/polarity.dart';
import 'package:flui/features/training/domain/skill.dart';

/// The closed catalog of behaviors a training attempt can surface.
///
/// Thinking and language codes are AI-observed (`speech-analyze`'s LLM
/// evaluation); voice and fluency codes are always client-measured, never
/// judged by the LLM (design D12).
///
/// Closed and three-way-parity checked: this catalog,
/// `supabase/functions/speech-analyze/behavior_codes.json` (the wire-format
/// source of truth), and `content/`'s challenge-content validator all share
/// the same [wireCode] set.
enum BehaviorCode {
  // Thinking — AI-observed.
  mainPointLate(SkillArea.thinking, Polarity.opportunity, 'main_point_late'),
  noClearStructure(
    SkillArea.thinking,
    Polarity.opportunity,
    'no_clear_structure',
  ),
  missingExample(SkillArea.thinking, Polarity.opportunity, 'missing_example'),
  noClosing(SkillArea.thinking, Polarity.opportunity, 'no_closing'),
  clearMainPoint(SkillArea.thinking, Polarity.strength, 'clear_main_point'),
  orderedIdeas(SkillArea.thinking, Polarity.strength, 'ordered_ideas'),

  // Language — AI-observed.
  vagueWord(SkillArea.language, Polarity.opportunity, 'vague_word'),
  repeatedWord(SkillArea.language, Polarity.opportunity, 'repeated_word'),
  weakConnector(SkillArea.language, Polarity.opportunity, 'weak_connector'),
  registerMismatch(
    SkillArea.language,
    Polarity.opportunity,
    'register_mismatch',
  ),
  preciseWord(SkillArea.language, Polarity.strength, 'precise_word'),
  variedVocabulary(SkillArea.language, Polarity.strength, 'varied_vocabulary'),

  // Voice / Fluency — client-measured, never AI-judged.
  paceFast(SkillArea.voice, Polarity.opportunity, 'pace_fast'),
  paceSlow(SkillArea.voice, Polarity.opportunity, 'pace_slow'),
  longPauses(SkillArea.fluency, Polarity.opportunity, 'long_pauses'),
  fillerHeavy(SkillArea.fluency, Polarity.opportunity, 'filler_heavy'),
  volumeUnstable(SkillArea.voice, Polarity.opportunity, 'volume_unstable'),
  steadyPace(SkillArea.voice, Polarity.strength, 'steady_pace'),
  controlledFillers(SkillArea.fluency, Polarity.strength, 'controlled_fillers'),
  steadyVolume(SkillArea.voice, Polarity.strength, 'steady_volume'),
  usefulPauses(SkillArea.fluency, Polarity.strength, 'useful_pauses');

  new(this.area, this.polarity, this.wireCode);

  final SkillArea area;
  final Polarity polarity;

  /// The snake_case identifier shared with the wire catalog and `content/`.
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
