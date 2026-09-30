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

  /// HOY's own speaking loop (U15a, design D41), a branch child of [today]
  /// (design D30 — no `parentNavigatorKey`, unlike [timeBudget]).
  static const todayTrain = '$today/train';
  static const words = '/words';
  static const progress = '/progress';

  /// The old Habla/speaking-challenge tab's landing route. Retired (U16,
  /// design D32) — deep links redirect to [train] via [retiredRoutes].
  static const speakingChallenge = '/speaking/challenge';

  /// The old challenge-recording route, nested under [speakingChallenge].
  /// Retired alongside it (U16) — see [retiredRoutes].
  static const speakingChallengeLive = '$speakingChallenge/live';

  /// ENTRENAR's tab landing: 4 training-mode cards (U16), replacing the
  /// old Habla/speaking-challenge tab.
  static const train = '/train';

  /// One training-lab mode's own loop, nested under [train] but rendered
  /// on the branch navigator, not a full-screen take-over (design D30).
  static String trainMode(TrainingMode mode) => '$train/${mode.name}';

  /// Was a tab of its own. "Repaso extra" now lives on Hoy, and the scenes
  /// live in the word detail, so both redirect instead of 404-ing old links.
  static const practice = '/practice';
  static const reading = '/reading';

  /// Deep links to retired routes redirect here instead of 404-ing.
  /// [speakingChallenge]/[speakingChallengeLive] were the old Habla tab
  /// (U16, design D32), replaced by [train].
  static const Map<String, String> retiredRoutes = {
    practice: today,
    reading: words,
    speakingChallenge: train,
    speakingChallengeLive: train,
  };

  /// The mandatory diagnosis (design part-3 §11, D16) — not part of any
  /// shell branch: the gate blocks every tab, so all 3 pages take over the
  /// root navigator directly, the same pattern as [session].
  static const diagnosis = '/diagnosis';
  static const diagnosisLive = '$diagnosis/live';
  static const diagnosisResult = '$diagnosis/result';
  static const Set<String> diagnosisRoutes = {
    diagnosis,
    diagnosisLive,
    diagnosisResult,
  };

  // Full screen, outside the shell.
  static const session = '/session';
  static const sessionReview = '/session?mode=review';
  static const sessionFree = '/session?mode=free';

  static String wordDetail(String wordId) =>
      '$words/${Uri.encodeComponent(wordId)}';

  /// PALABRAS' own spoken-use loop (U17, design §19.4): a branch child of
  /// [wordDetail], not a full-screen take-over (design D30, matches
  /// [todayTrain]/[trainMode]). Reached from `TodayWordTarget`/
  /// `WordSpeakTarget`'s first captured attempt, never tapped directly.
  static String wordSpeak(String wordId) => '${wordDetail(wordId)}/speak';

  static String wordDetailFromCategory({
    required String wordId,
    required String returnLocation,
  }) => Uri(
    path: wordDetail(wordId),
    queryParameters: {'returnTo': returnLocation},
  ).toString();

  /// Routes that need today's time budget first (asked once per local day).
  /// "Tu progreso" stays reachable for the account and sign out.
  ///
  /// [today] itself no longer needs a persisted session first (U15a,
  /// design D41) — it shows duration chips and a provisional plan instead
  /// — but its own loop route ([todayTrain]) picks up the requirement in
  /// its place, since starting the loop always implies a session already
  /// exists by then.
  static bool needsDailyBudget(String path) =>
      path == todayTrain ||
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
