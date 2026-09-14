import 'package:flui/features/onboarding/domain/onboarding_answers.dart';
import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/themes/domain/theme.dart';

/// Ranks themes from the two pre-signup answers, so the daily prompt can open
/// on three that actually fit.
///
/// Why three, and why an "Explorar" door next to them: Patall, Cooper and
/// Robinson (2008) found the motivational benefit of choice is largest at
/// **two to four** options and falls away when a list grows past that;
/// Scheibehenne, Greifeneder and Todd (2010) then showed in a meta-analysis
/// that long lists are not actively *harmful*, merely not helpful. So the
/// prompt shows [recommendedCount] cards plus a full list for anyone who wants
/// it, and the user keeps at most [maxUserThemes] themes of their own. There
/// is no minimum streak on a theme: changing it any day is free.
abstract final class ThemeRecommender {
  /// Cards shown in the daily prompt, next to "Explorar" and "Sorpréndeme".
  static const recommendedCount = 3;

  /// "Tus temas" never grows past this: a shortlist is a shortlist.
  static const maxUserThemes = 3;

  /// Every offered theme, best fit first. Ties keep catalog order, so the
  /// list never shuffles between two builds of the same screen.
  static List<Theme> rank({
    required List<Theme> themes,
    required OnboardingAnswers answers,
  }) {
    final offered = [
      for (final theme in themes)
        if (theme.isOffered) theme,
    ];
    final scores = {
      for (final theme in offered) theme.id: scoreOf(theme, answers),
    };
    return offered..sort((a, b) {
      final byScore = scores[b.id]!.compareTo(scores[a.id]!);
      if (byScore != 0) return byScore;
      return a.sortOrder.compareTo(b.sortOrder);
    });
  }

  /// The top [recommendedCount] themes, or fewer when the catalog is smaller.
  static List<Theme> recommend({
    required List<Theme> themes,
    required OnboardingAnswers answers,
  }) => rank(themes: themes, answers: answers).take(recommendedCount).toList();

  /// How well one theme matches the answers. Higher is better; 0 is neutral,
  /// which is what an unanswered onboarding produces for every theme.
  static int scoreOf(Theme theme, OnboardingAnswers answers) {
    var score = 0;
    for (final scene in answers.contexts) {
      score += _sceneWeights[scene]?[theme.family] ?? 0;
    }
    final tone = answers.tone;
    if (tone != null) score += _toneWeights[tone]?[theme.family] ?? 0;
    return score;
  }

  /// "¿Dónde te faltan palabras?" → theme families.
  ///
  /// Each scene names the family it is about and, where the overlap is real,
  /// one adjacent family at half the weight. A scene never scores a family it
  /// has nothing to do with: a user who only picked "familia" should not be
  /// nudged towards executive writing.
  static const _sceneWeights = <Scene, Map<ThemeFamily, int>>{
    Scene.trabajo: {ThemeFamily.trabajo: 4, ThemeFamily.precision: 2},
    Scene.social: {ThemeFamily.social: 4, ThemeFamily.emocion: 2},
    Scene.entrevista: {ThemeFamily.publico: 4, ThemeFamily.trabajo: 2},
    Scene.familia: {ThemeFamily.emocion: 4, ThemeFamily.social: 2},
  };

  /// "¿Cómo quieres sonar?" → theme families. Tone is a single answer and a
  /// softer signal than where the user struggles, so it weighs less.
  static const _toneWeights = <SpeakingTone, Map<ThemeFamily, int>>{
    SpeakingTone.precise: {ThemeFamily.precision: 3, ThemeFamily.trabajo: 1},
    SpeakingTone.warm: {ThemeFamily.emocion: 3, ThemeFamily.social: 2},
    SpeakingTone.confident: {ThemeFamily.publico: 3, ThemeFamily.trabajo: 1},
  };
}
