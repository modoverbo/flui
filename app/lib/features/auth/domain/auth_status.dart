/// Whether a user session exists.
enum AuthStatus {
  /// The session is still being restored (app start, page reload).
  unknown,
  signedOut,
  signedIn,
}
