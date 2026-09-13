/// Mastery state of a word for one user (`word_progress.state`).
enum WordState {
  /// Introduced, not yet retrieved unaided.
  nueva,

  /// Being consolidated with spaced reviews.
  practica,

  /// Active vocabulary ("Ya es tuya").
  tuya,
}
