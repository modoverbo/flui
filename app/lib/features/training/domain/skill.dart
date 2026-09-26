/// The three broad competencies the training engine measures.
enum Skill { thinking, language, voice }

/// A skill area observable in an attempt.
///
/// [fluency] is an observable sub-area of [Skill.voice] (pace, pauses,
/// fillers, volume), never a skill of its own.
enum SkillArea {
  thinking,
  language,
  voice,
  fluency;

  /// The parent [Skill] this area contributes to.
  Skill get skill => switch (this) {
    SkillArea.thinking => Skill.thinking,
    SkillArea.language => Skill.language,
    SkillArea.voice || SkillArea.fluency => Skill.voice,
  };
}
