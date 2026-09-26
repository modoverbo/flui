/// Where a training loop runs. Drives audio-retention and progression rules
/// that differ by context (D33): `quick` practice is never a milestone and
/// is excluded from progression.
enum TrainingContext { diagnosis, daily, lab, word, quick }
