/// The authored training/diagnosis challenge model.
///
/// `fromMap` assumes the map already passed the schema validator; it throws
/// [FormatException] on anything it cannot read, so a schema hole can never
/// become a silent default. Mirrors `content/lib/src/model/word.dart`.
library;

enum ChallengeStatus { draft, validated, gated, approved }

enum ChallengePurpose { training, diagnosis }

enum Skill { thinking, language, voice }

enum TrainingMode {
  thinkAndSpeak,
  speakWithPrecision,
  masterYourVoice,
  realSituations,
}

const _trainingModeWireNames = <TrainingMode, String>{
  TrainingMode.thinkAndSpeak: 'think_and_speak',
  TrainingMode.speakWithPrecision: 'speak_with_precision',
  TrainingMode.masterYourVoice: 'master_your_voice',
  TrainingMode.realSituations: 'real_situations',
};

/// The wire-format (snake_case) name shared with the challenge YAML and the
/// database, mirroring the app's `TrainingMode` (not imported: `content/` is
/// a pure-Dart package independent of `app/`).
extension TrainingModeWire on TrainingMode {
  String get wireName => _trainingModeWireNames[this]!;
}

T _enumByName<T extends Enum>(
  List<T> values,
  Map<T, String>? names,
  Object? raw,
  String field,
) {
  final text = raw is String ? raw : null;
  if (text == null) {
    throw FormatException('$field must be a string, got $raw');
  }
  for (final value in values) {
    final name = names?[value] ?? value.name;
    if (name == text) return value;
  }
  throw FormatException('$field has unknown value "$text"');
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('$key must be a string, got ${value.runtimeType}');
  }
  return value;
}

String? _stringOrNull(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key must be a string, got ${value.runtimeType}');
  }
  return value;
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('$key must be an integer, got ${value.runtimeType}');
  }
  return value;
}

int? _intOrNull(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('$key must be an integer, got ${value.runtimeType}');
  }
  return value;
}

List<String> _stringList(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('$key must be a list, got ${value.runtimeType}');
  }
  return [
    for (final item in value)
      if (item is String)
        item
      else
        throw FormatException('$key items must be strings'),
  ];
}

/// One authored training or diagnosis challenge.
///
/// `focusBehaviors` holds [content/lib/src/model/behavior_catalog.dart]'s
/// wire codes as plain strings; membership in that closed catalog is a
/// content validator's job (`FocusBehaviorsValidator`), not this model's.
final class Challenge {
  const Challenge({
    required this.slug,
    required this.status,
    required this.purpose,
    required this.skill,
    required this.difficulty,
    required this.prompt,
    required this.focus,
    required this.targetSeconds,
    this.diagnosisSlot,
    this.mode,
    this.cue,
    this.focusBehaviors = const [],
    this.transferPrompts = const [],
    this.id,
    this.sortOrder,
  });

  factory Challenge.fromMap(Map<String, Object?> map) => Challenge(
    slug: _string(map, 'slug'),
    status: _enumByName(
      ChallengeStatus.values,
      null,
      map['status'],
      'status',
    ),
    purpose: _enumByName(
      ChallengePurpose.values,
      null,
      map['purpose'],
      'purpose',
    ),
    diagnosisSlot: _intOrNull(map, 'diagnosis_slot'),
    skill: _enumByName(Skill.values, null, map['skill'], 'skill'),
    mode: map['mode'] == null
        ? null
        : _enumByName(
            TrainingMode.values,
            _trainingModeWireNames,
            map['mode'],
            'mode',
          ),
    difficulty: _int(map, 'difficulty'),
    prompt: _string(map, 'prompt'),
    cue: _stringOrNull(map, 'cue'),
    focus: _string(map, 'focus'),
    focusBehaviors: _stringList(map, 'focus_behaviors'),
    transferPrompts: _stringList(map, 'transfer_prompts'),
    targetSeconds: _int(map, 'target_seconds'),
    id: _stringOrNull(map, 'id'),
    sortOrder: _intOrNull(map, 'sort_order'),
  );

  final String slug;
  final ChallengeStatus status;
  final ChallengePurpose purpose;

  /// 1-3, required iff [purpose] is [ChallengePurpose.diagnosis].
  final int? diagnosisSlot;
  final Skill skill;

  /// Required iff [purpose] is [ChallengePurpose.training].
  final TrainingMode? mode;
  final int difficulty;
  final String prompt;
  final String? cue;
  final String focus;
  final List<String> focusBehaviors;
  final List<String> transferPrompts;
  final int targetSeconds;

  /// Database identity, preserved so emission stays byte stable.
  final String? id;

  /// Emission order. Never authored: assigned by
  /// `content/lib/src/sql/seed_emitter.dart`'s deterministic ordering.
  final int? sortOrder;
}
