import 'package:flui/features/reading/domain/reading.dart';
import 'package:meta/meta.dart';

/// How the user wants to sound ("¿Cómo quieres sonar?").
enum SpeakingTone { precise, warm, confident }

/// What the two pre-signup questions answered.
///
/// Stored on the device for now; the account does not exist yet when they
/// are asked.
// TODO(flui): move to an `onboarding_answers` table once the shape has
// settled, keyed by `auth.uid()`, and upload whatever is on the device the
// first time the user signs in. Inventing the schema before the questions
// are final would only migrate it twice.
@immutable
final class OnboardingAnswers {
  const new({this.contexts = const {}, this.tone});

  factory fromJson(Map<String, Object?> json) {
    final contexts = json['contexts'];
    final tone = json['tone'];
    return OnboardingAnswers(
      contexts: {
        if (contexts is List)
          for (final value in contexts)
            ?Scene.values.where((scene) => scene.name == value).firstOrNull,
      },
      tone: SpeakingTone.values
          .where((value) => value.name == tone)
          .firstOrNull,
    );
  }

  static const empty = OnboardingAnswers();

  /// Where the user's vocabulary lets them down. Multi-select, may be empty.
  final Set<Scene> contexts;

  /// How they want to sound. Single-select.
  final SpeakingTone? tone;

  bool get isEmpty => contexts.isEmpty && tone == null;

  /// Both questions answered: the paywall can echo them back.
  bool get isComplete => contexts.isNotEmpty && tone != null;

  /// Scenes in catalog order, so the copy never reads back at random.
  List<Scene> get orderedContexts => [
    for (final scene in Scene.values)
      if (contexts.contains(scene)) scene,
  ];

  OnboardingAnswers withContext(Scene scene, {required bool selected}) =>
      OnboardingAnswers(
        contexts: {
          for (final value in contexts)
            if (value != scene) value,
          if (selected) scene,
        },
        tone: tone,
      );

  OnboardingAnswers withTone(SpeakingTone value) =>
      OnboardingAnswers(contexts: contexts, tone: value);

  Map<String, Object?> toJson() => {
    'contexts': [for (final scene in orderedContexts) scene.name],
    'tone': tone?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is OnboardingAnswers &&
      other.tone == tone &&
      other.contexts.length == contexts.length &&
      other.contexts.containsAll(contexts);

  @override
  int get hashCode => Object.hash(tone, Object.hashAllUnordered(contexts));

  @override
  String toString() => 'OnboardingAnswers($orderedContexts, $tone)';
}

/// Joins the chosen scenes into one phrase: "el trabajo y las entrevistas".
String joinContexts(List<String> labels) => switch (labels.length) {
  0 => '',
  1 => labels.single,
  _ => '${labels.sublist(0, labels.length - 1).join(', ')} y ${labels.last}',
};
