/// What the router knows about today's session.
enum DailyGate {
  /// Learning data has not loaded yet.
  unknown,

  /// No `daily_sessions` row for today: ask for the time budget.
  needsBudget,

  /// Today's budget is chosen.
  planned,

  /// Learning data failed to load; screens show the error and a retry.
  unavailable,
}
