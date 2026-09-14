/// The authored word model.
///
/// `fromMap` assumes the map already passed the schema validator; it throws
/// [FormatException] on anything it cannot read, so a schema hole can never
/// become a silent default.
library;

enum WordStatus { draft, validated, gated, approved }

enum PartOfSpeech { adjetivo, adverbio, conector, sustantivo, verbo }

enum Register { neutral, culto, coloquial }

enum DistractorType { paronym, nearSynonym, register }

enum Scene { trabajo, social, entrevista, familia }

enum ConversationType { practica, emocional, social }

const distractorTypeNames = <DistractorType, String>{
  DistractorType.paronym: 'paronym',
  DistractorType.nearSynonym: 'near_synonym',
  DistractorType.register: 'register',
};

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

double? _doubleOrNull(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is! double) {
    throw FormatException('$key must be a number, got ${value.runtimeType}');
  }
  return value;
}

bool _bool(Map<String, Object?> map, String key, {bool orElse = false}) {
  final value = map[key];
  if (value == null) return orElse;
  if (value is! bool) {
    throw FormatException('$key must be a boolean, got ${value.runtimeType}');
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

List<Map<String, Object?>> _mapList(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('$key must be a list, got ${value.runtimeType}');
  }
  return [
    for (final item in value)
      if (item is Map<String, Object?>)
        item
      else
        throw FormatException('$key items must be maps'),
  ];
}

final class Replacement {
  const Replacement({required this.before, required this.after});

  factory Replacement.fromMap(Map<String, Object?> map) =>
      Replacement(before: _string(map, 'before'), after: _string(map, 'after'));

  final String before;
  final String after;
}

final class ThemeRef {
  const ThemeRef({required this.slug, required this.relevance});

  factory ThemeRef.fromMap(Map<String, Object?> map) =>
      ThemeRef(slug: _string(map, 'slug'), relevance: _int(map, 'relevance'));

  final String slug;
  final int relevance;
}

final class Tags {
  const Tags({
    required this.comodin,
    required this.funcion,
    required this.canal,
    required this.formalidad,
    required this.variedad,
  });

  factory Tags.fromMap(Map<String, Object?> map) => Tags(
    comodin: _stringList(map, 'comodin'),
    funcion: _stringList(map, 'funcion'),
    canal: _string(map, 'canal'),
    formalidad: _string(map, 'formalidad'),
    variedad: _string(map, 'variedad'),
  );

  final List<String> comodin;
  final List<String> funcion;
  final String canal;
  final String formalidad;
  final String variedad;
}

final class Confusion {
  const Confusion({
    required this.confusedWith,
    required this.difference,
    this.memoryTrick,
  });

  factory Confusion.fromMap(Map<String, Object?> map) => Confusion(
    confusedWith: _string(map, 'confused_with'),
    difference: _string(map, 'difference'),
    memoryTrick: _stringOrNull(map, 'memory_trick'),
  );

  final String confusedWith;
  final String difference;
  final String? memoryTrick;
}

final class ExerciseOption {
  const ExerciseOption({
    required this.position,
    required this.text,
    required this.isCorrect,
    this.distractorType,
    this.whyNot,
    this.hintSpecific,
  });

  factory ExerciseOption.fromMap(Map<String, Object?> map) => ExerciseOption(
    position: _int(map, 'position'),
    text: _string(map, 'text'),
    isCorrect: _bool(map, 'is_correct'),
    distractorType: map['distractor_type'] == null
        ? null
        : _enumByName(
            DistractorType.values,
            distractorTypeNames,
            map['distractor_type'],
            'distractor_type',
          ),
    whyNot: _stringOrNull(map, 'why_not'),
    hintSpecific: _stringOrNull(map, 'hint_specific'),
  );

  final int position;
  final String text;
  final bool isCorrect;
  final DistractorType? distractorType;
  final String? whyNot;
  final String? hintSpecific;
}

final class Exercise {
  const Exercise({
    required this.position,
    required this.sentence,
    required this.hintGeneral,
    required this.explanation,
    required this.options,
    this.id,
  });

  factory Exercise.fromMap(Map<String, Object?> map) => Exercise(
    position: _int(map, 'position'),
    sentence: _string(map, 'sentence'),
    hintGeneral: _string(map, 'hint_general'),
    explanation: _string(map, 'explanation'),
    id: _stringOrNull(map, 'id'),
    options: [
      for (final option in _mapList(map, 'options'))
        ExerciseOption.fromMap(option),
    ],
  );

  final int position;
  final String sentence;
  final String hintGeneral;
  final String explanation;
  final List<ExerciseOption> options;

  /// Database identity, preserved so emission stays byte stable.
  final String? id;

  ExerciseOption get correctOption => options.firstWhere((o) => o.isCorrect);

  List<ExerciseOption> get distractors => [
    for (final option in options)
      if (!option.isCorrect) option,
  ];
}

final class Reading {
  const Reading({
    required this.position,
    required this.scene,
    required this.conversationType,
    required this.title,
    required this.body,
    required this.beforePhrase,
    required this.afterPhrase,
  });

  factory Reading.fromMap(Map<String, Object?> map) => Reading(
    position: _int(map, 'position'),
    scene: _enumByName(Scene.values, null, map['scene'], 'scene'),
    conversationType: _enumByName(
      ConversationType.values,
      null,
      map['conversation_type'],
      'conversation_type',
    ),
    title: _string(map, 'title'),
    body: _string(map, 'body'),
    beforePhrase: _string(map, 'before_phrase'),
    afterPhrase: _string(map, 'after_phrase'),
  );

  final int position;
  final Scene scene;
  final ConversationType conversationType;
  final String title;
  final String body;
  final String beforePhrase;
  final String afterPhrase;
}

final class Metrics {
  const Metrics({
    this.zipfOverall,
    this.zipfByCountry = const {},
    this.dispersionDp,
    this.pedantryProxy,
    this.familySize,
    this.metricsPending = false,
  });

  factory Metrics.fromMap(Map<String, Object?> map) => Metrics(
    zipfOverall: _doubleOrNull(map, 'zipf_overall'),
    zipfByCountry: {
      for (final entry
          in (map['zipf_by_country'] as Map<String, Object?>? ?? const {})
              .entries)
        entry.key: (entry.value! as num).toDouble(),
    },
    dispersionDp: _doubleOrNull(map, 'dispersion_dp'),
    pedantryProxy: _doubleOrNull(map, 'pedantry_proxy'),
    familySize: _intOrNull(map, 'family_size'),
    metricsPending: _bool(map, 'metrics_pending'),
  );

  final double? zipfOverall;
  final Map<String, double> zipfByCountry;
  final double? dispersionDp;
  final double? pedantryProxy;
  final int? familySize;
  final bool metricsPending;
}

final class Provenance {
  const Provenance({this.generator, this.gate, this.checkedOn});

  factory Provenance.fromMap(Map<String, Object?> map) => Provenance(
    generator: _stringOrNull(map, 'generator'),
    gate: _stringOrNull(map, 'gate'),
    checkedOn: _stringOrNull(map, 'checked_on'),
  );

  final String? generator;
  final String? gate;
  final String? checkedOn;
}

final class Word {
  const Word({
    required this.schemaVersion,
    required this.slug,
    required this.status,
    required this.lemma,
    required this.partOfSpeech,
    required this.syllables,
    required this.stressedSyllable,
    required this.explanation,
    required this.exampleSentence,
    required this.register,
    required this.pedantryRisk,
    required this.collocations,
    required this.replaces,
    required this.family,
    required this.themes,
    required this.tags,
    required this.confusions,
    required this.exercises,
    required this.readings,
    this.semanticSetId,
    this.ipaLatam,
    this.ipaEs,
    this.usageTip,
    this.whenNotToUse,
    this.metrics,
    this.provenance,
    this.id,
    this.sortOrder,
  });

  factory Word.fromMap(Map<String, Object?> map) => Word(
    schemaVersion: _int(map, 'schema_version'),
    slug: _string(map, 'slug'),
    status: _enumByName(WordStatus.values, null, map['status'], 'status'),
    lemma: _string(map, 'lemma'),
    partOfSpeech: _enumByName(
      PartOfSpeech.values,
      null,
      map['part_of_speech'],
      'part_of_speech',
    ),
    syllables: _stringList(map, 'syllables'),
    stressedSyllable: _int(map, 'stressed_syllable'),
    ipaLatam: _stringOrNull(map, 'ipa_latam'),
    ipaEs: _stringOrNull(map, 'ipa_es'),
    explanation: _string(map, 'explanation'),
    exampleSentence: _string(map, 'example_sentence'),
    register: _enumByName(Register.values, null, map['register'], 'register'),
    pedantryRisk: _int(map, 'pedantry_risk'),
    usageTip: _stringOrNull(map, 'usage_tip'),
    whenNotToUse: _stringOrNull(map, 'when_not_to_use'),
    collocations: _stringList(map, 'collocations'),
    replaces: [
      for (final r in _mapList(map, 'replaces')) Replacement.fromMap(r),
    ],
    family: _stringList(map, 'family'),
    semanticSetId: _stringOrNull(map, 'semantic_set_id'),
    themes: [for (final t in _mapList(map, 'themes')) ThemeRef.fromMap(t)],
    tags: Tags.fromMap((map['tags'] as Map<String, Object?>?) ?? const {}),
    confusions: [
      for (final c in _mapList(map, 'confusions')) Confusion.fromMap(c),
    ],
    exercises: [
      for (final e in _mapList(map, 'exercises')) Exercise.fromMap(e),
    ],
    readings: [for (final r in _mapList(map, 'readings')) Reading.fromMap(r)],
    metrics: map['metrics'] == null
        ? null
        : Metrics.fromMap(map['metrics']! as Map<String, Object?>),
    provenance: map['provenance'] == null
        ? null
        : Provenance.fromMap(map['provenance']! as Map<String, Object?>),
    id: _stringOrNull(map, 'id'),
    sortOrder: _intOrNull(map, 'sort_order'),
  );

  final int schemaVersion;
  final String slug;
  final WordStatus status;
  final String lemma;
  final PartOfSpeech partOfSpeech;
  final List<String> syllables;
  final int stressedSyllable;
  final String? ipaLatam;
  final String? ipaEs;
  final String explanation;
  final String exampleSentence;
  final Register register;
  final int pedantryRisk;
  final String? usageTip;
  final String? whenNotToUse;
  final List<String> collocations;
  final List<Replacement> replaces;
  final List<String> family;

  /// Synonym / antonym / category-mate group, or null when the word is in
  /// none. Two words that share one are never introduced within 7 days of
  /// each other (learning-method §7): Tinkham (1993) and Nation (2000) found
  /// that kind of cluster interferes, while a shared theme does not.
  final String? semanticSetId;

  final List<ThemeRef> themes;
  final Tags tags;
  final List<Confusion> confusions;
  final List<Exercise> exercises;
  final List<Reading> readings;
  final Metrics? metrics;
  final Provenance? provenance;

  /// Database identity, preserved so emission stays byte stable.
  final String? id;

  /// Introduction order used by the session planner.
  final int? sortOrder;
}
