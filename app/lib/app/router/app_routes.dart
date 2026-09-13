/// Route paths. Keep them lowercase: go_router matching is case-sensitive.
abstract final class AppRoutes {
  static const root = '/';
  static const splash = '/splash';

  // Public (signed out).
  static const welcome = '/welcome';
  static const intro = '/intro';
  static const login = '/login';
  static const register = '/register';
  static const resetPassword = '/reset-password';

  // Signed in without access.
  static const paywall = '/paywall';
  static const checkoutReturn = '/checkout/return';

  // App shell (signed in with access).
  static const today = '/today';
  static const timeBudget = '/today/time';
  static const words = '/words';
  static const practice = '/practice';
  static const reading = '/reading';
  static const progress = '/progress';

  static const Set<String> publicRoutes = {
    welcome,
    intro,
    login,
    register,
    resetPassword,
  };
  static const Set<String> accessFreeRoutes = {paywall, checkoutReturn};

  /// Splash location that returns to [from] once the state is known.
  static String splashFrom(Uri from) =>
      Uri(path: splash, queryParameters: {'from': from.toString()}).toString();
}
