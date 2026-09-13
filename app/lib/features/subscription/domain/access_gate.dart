/// What the router knows about the signed-in user's paid access.
enum AccessGate {
  /// `my_access()` has not answered yet.
  unknown,

  /// `my_access()` failed (for example, offline). The splash offers a retry.
  error,
  granted,
  denied,
}
