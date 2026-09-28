import 'package:flui/features/training/domain/training_mode.dart';

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

  // App shell (signed in with access): four tabs.
  static const today = '/today';
  static String categoryCatalog(
    String family, {
    String? themeId,
    double? scrollOffset,
  }) {
    final queryParameters = <String, String>{
      'theme': ?themeId,
      if (scrollOffset case final scrollOffset? when scrollOffset > 0)
        'offset': scrollOffset.toStringAsFixed(1),
    };
    if (queryParameters.isEmpty) return '$today/categories/$family';
    return Uri(
      path: '$today/categories/$family',
      queryParameters: queryParameters,
    ).toString();
  }

  static const timeBudget = '/today/time';
  static const words = '/words';
  static const progress = '/progress';

  /// Retired (U16): was Habla's tab landing, the speaking-challenge's own
  /// `ready` phase. Replaced by [train] — see [retiredRoutes].
  static const speakingChallenge = '/speaking/challenge';

  /// Retired alongside [speakingChallenge] — see [retiredRoutes].
  static const speakingChallengeLive = '$speakingChallenge/live';

  /// ENTRENAR's tab landing: 4 training-mode cards (U16), replacing the
  /// old Habla/speaking-challenge tab.
  static const train = '/train';

  /// One training-lab mode's own loop, nested under [train] but rendered
  /// on the branch navigator, not a full-screen take-over (design D30) —
  /// unlike the retired [speakingChallengeLive].
  static String trainMode(TrainingMode mode) => '$train/${mode.name}';

  /// Was a tab of its own. "Repaso extra" now lives on Hoy, and the scenes
  /// live in the word detail, so both redirect instead of 404-ing old links.
  static const practice = '/practice';
  static const reading = '/reading';
  static const Map<String, String> retiredRoutes = {
    practice: today,
    reading: words,
    speakingChallenge: train,
    speakingChallengeLive: train,
  };

  // Full screen, outside the shell.
  static const session = '/session';
  static const sessionReview = '/session?mode=review';
  static const sessionFree = '/session?mode=free';

  static String wordDetail(String wordId) =>
      '$words/${Uri.encodeComponent(wordId)}';

  static String wordDetailFromCategory({
    required String wordId,
    required String returnLocation,
  }) => Uri(
    path: wordDetail(wordId),
    queryParameters: {'returnTo': returnLocation},
  ).toString();

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
