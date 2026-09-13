/// Route paths. Keep them lowercase: go_router matching is case-sensitive.
abstract final class AppRoutes {
  static const root = '/';
  static const splash = '/splash';

  // Public (signed out).
  static const welcome = '/welcome';
  static const intro = '/intro';
  static const login = '/login';

  /// The paywall before the account exists: real prices, no email yet.
  static const plan = '/plan';
  static const register = '/register';
  static const resetPassword = '/reset-password';

  // Signed in without access.
  static const paywall = '/paywall';
  static const checkoutReturn = '/checkout/return';

  // App shell (signed in with access): three tabs.
  static const today = '/today';
  static const timeBudget = '/today/time';
  static const words = '/words';
  static const progress = '/progress';

  /// Was a tab of its own. "Repaso extra" now lives on Hoy, and the scenes
  /// live in the word detail, so both redirect instead of 404-ing old links.
  static const practice = '/practice';
  static const reading = '/reading';
  static const Map<String, String> retiredRoutes = {
    practice: today,
    reading: words,
  };

  // Full screen, outside the shell.
  static const session = '/session';
  static const sessionReview = '/session?mode=review';
  static const sessionFree = '/session?mode=free';

  static String wordDetail(String wordId) =>
      '$words/${Uri.encodeComponent(wordId)}';

  /// Routes that need today's time budget first (asked once per local day).
  /// "Tu progreso" stays reachable for the account and sign out.
  static bool needsDailyBudget(String path) =>
      path == today ||
      path == session ||
      path == words ||
      path.startsWith('$words/');

  static const Set<String> publicRoutes = {
    welcome,
    intro,
    plan,
    login,
    register,
    resetPassword,
  };
  static const Set<String> accessFreeRoutes = {paywall, checkoutReturn};

  /// Splash location that returns to [from] once the state is known.
  static String splashFrom(Uri from) =>
      Uri(path: splash, queryParameters: {'from': from.toString()}).toString();
}
