import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/structural.dart';
import 'package:content/src/validation/validator.dart';

/// Structural conformance of a raw word file, run before the model is built.
///
/// It mirrors `content/schema/word.schema.json`; a test keeps the two key sets
/// in sync. Everything downstream may assume a clean map.
final class SchemaConformanceValidator extends RawWordValidator {
  const SchemaConformanceValidator();

  static const requiredKeys = <String>{
    'schema_version',
    'slug',
    'status',
    'lemma',
    'part_of_speech',
    'syllables',
    'stressed_syllable',
    'explanation',
    'example_sentence',
    'register',
    'pedantry_risk',
    'collocations',
    'replaces',
    'family',
    'themes',
    'tags',
    'confusions',
    'exercises',
    'readings',
  };

  static const optionalKeys = <String>{
    'id',
    'sort_order',
    'semantic_set_id',
    'ipa_latam',
    'ipa_es',
    'usage_tip',
    'when_not_to_use',
    'metrics',
    'provenance',
  };

  static Set<String> get knownKeys => {...requiredKeys, ...optionalKeys};

  static const _statuses = {'draft', 'validated', 'gated', 'approved'};
  static const _partsOfSpeech = {
    'adjetivo',
    'adverbio',
    'conector',
    'sustantivo',
    'verbo',
  };
  static const _registers = {'neutral', 'culto', 'coloquial'};
  static const _canales = {'hablado', 'escrito', 'ambos'};
  static const _formalidades = {'informal', 'neutral', 'formal'};
  static const _variedades = {'panhispanico', 'latam', 'es'};
  static const _distractorTypes = {'paronym', 'near_synonym', 'register'};
  static const _scenes = {'trabajo', 'social', 'entrevista', 'familia'};
  static const _conversationTypes = {'practica', 'emocional', 'social'};

  static final _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  @override
  String get code => 'schema';

  @override
  String get description =>
      'the file conforms to content/schema/word.schema.json';

  @override
  Severity get severity => Severity.blocking;

  @override
  List<Issue> validateRaw(String slug, Map<String, Object?> raw) {
    final issues = <Issue>[];
    void fail(String location, String message) => issues.add(
      Issue(
        code: code,
        severity: severity,
        slug: slug,
        location: location,
        message: message,
      ),
    );

    for (final key in requiredKeys) {
      if (!raw.containsKey(key)) fail(key, 'missing required key "$key"');
    }
    for (final key in raw.keys) {
      if (!knownKeys.contains(key)) fail(key, 'unknown key "$key"');
    }

    void expectString(String key, Object? value, {bool nullable = false}) {
      if (value == null && nullable) return;
      if (value is! String || value.trim().isEmpty) {
        fail(key, '"$key" must be a non-empty string');
      }
    }

    void expectInt(String key, Object? value, {int? min, int? max}) {
      if (value is! int) {
        fail(key, '"$key" must be an integer');
        return;
      }
      if (min != null && value < min) fail(key, '"$key" must be >= $min');
      if (max != null && value > max) fail(key, '"$key" must be <= $max');
    }

    void expectEnum(String key, Object? value, Set<String> allowed) {
      if (value is! String || !allowed.contains(value)) {
        fail(key, '"$key" must be one of ${allowed.toList()..sort()}');
      }
    }

    List<Object?>? expectList(
      String key,
      Object? value, {
      int? min,
      int? max,
    }) {
      if (value is! List) {
        fail(key, '"$key" must be a list');
        return null;
      }
      if (min != null && value.length < min) {
        fail(key, '"$key" needs at least $min items, found ${value.length}');
      }
      if (max != null && value.length > max) {
        fail(key, '"$key" allows at most $max items, found ${value.length}');
      }
      return value;
    }

    Map<String, Object?>? expectMap(String key, Object? value) {
      if (value is! Map<String, Object?>) {
        fail(key, '"$key" must be a map');
        return null;
      }
      return value;
    }

    if (raw.containsKey('schema_version')) {
      expectInt('schema_version', raw['schema_version'], min: 1, max: 1);
    }
    if (raw.containsKey('slug')) {
      final value = raw['slug'];
      if (value is! String || !_slugPattern.hasMatch(value)) {
        fail('slug', 'slug must be kebab-case ([a-z0-9] and single hyphens)');
      }
    }
    if (raw.containsKey('status')) {
      expectEnum('status', raw['status'], _statuses);
    }
    if (raw.containsKey('lemma')) expectString('lemma', raw['lemma']);
    if (raw.containsKey('part_of_speech')) {
      expectEnum('part_of_speech', raw['part_of_speech'], _partsOfSpeech);
    }
    if (raw.containsKey('syllables')) {
      final list = expectList('syllables', raw['syllables'], min: 1);
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          expectString('syllables[$i]', list[i]);
        }
      }
    }
    if (raw.containsKey('stressed_syllable')) {
      expectInt('stressed_syllable', raw['stressed_syllable'], min: 1);
    }
    expectString('ipa_latam', raw['ipa_latam'], nullable: true);
    expectString('ipa_es', raw['ipa_es'], nullable: true);
    if (raw.containsKey('explanation')) {
      expectString('explanation', raw['explanation']);
    }
    if (raw.containsKey('example_sentence')) {
      expectString('example_sentence', raw['example_sentence']);
    }
    if (raw.containsKey('register')) {
      expectEnum('register', raw['register'], _registers);
    }
    if (raw.containsKey('pedantry_risk')) {
      expectInt('pedantry_risk', raw['pedantry_risk'], min: 1, max: 3);
    }
    expectString('usage_tip', raw['usage_tip'], nullable: true);
    expectString('when_not_to_use', raw['when_not_to_use'], nullable: true);
    if (raw.containsKey('id')) expectString('id', raw['id'], nullable: true);
    if (raw['semantic_set_id'] != null) {
      final value = raw['semantic_set_id'];
      if (value is! String || !_slugPattern.hasMatch(value)) {
        fail(
          'semantic_set_id',
          'semantic_set_id must be kebab-case ([a-z0-9] and single hyphens)',
        );
      }
    }
    if (raw['sort_order'] != null) {
      expectInt('sort_order', raw['sort_order'], min: 1);
    }

    if (raw.containsKey('collocations')) {
      final list = expectList('collocations', raw['collocations']);
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          expectString('collocations[$i]', list[i]);
        }
      }
    }
    if (raw.containsKey('family')) {
      final list = expectList('family', raw['family']);
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          expectString('family[$i]', list[i]);
        }
      }
    }
    if (raw.containsKey('replaces')) {
      final list = expectList('replaces', raw['replaces'], min: 2);
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final map = expectMap('replaces[$i]', list[i]);
          if (map == null) continue;
          _requireExactly(map, {'before', 'after'}, 'replaces[$i]', fail);
          expectString('replaces[$i].before', map['before']);
          expectString('replaces[$i].after', map['after']);
        }
      }
    }
    if (raw.containsKey('themes')) {
      final list = expectList('themes', raw['themes'], min: 1, max: 3);
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final map = expectMap('themes[$i]', list[i]);
          if (map == null) continue;
          _requireExactly(map, {'slug', 'relevance'}, 'themes[$i]', fail);
          expectString('themes[$i].slug', map['slug']);
          expectInt('themes[$i].relevance', map['relevance'], min: 1, max: 3);
        }
      }
    }
    if (raw.containsKey('tags')) {
      final map = expectMap('tags', raw['tags']);
      if (map != null) {
        _requireExactly(
          map,
          {'comodin', 'funcion', 'canal', 'formalidad', 'variedad'},
          'tags',
          fail,
        );
        expectList('tags.comodin', map['comodin']);
        expectList('tags.funcion', map['funcion']);
        expectEnum('tags.canal', map['canal'], _canales);
        expectEnum('tags.formalidad', map['formalidad'], _formalidades);
        expectEnum('tags.variedad', map['variedad'], _variedades);
      }
    }
    if (raw.containsKey('confusions')) {
      final list = expectList('confusions', raw['confusions'], min: 1);
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final map = expectMap('confusions[$i]', list[i]);
          if (map == null) continue;
          _requireKeys(
            map,
            {'confused_with', 'difference'},
            'confusions[$i]',
            fail,
          );
          _rejectUnknown(
            map,
            {'confused_with', 'difference', 'memory_trick'},
            'confusions[$i]',
            fail,
          );
          expectString('confusions[$i].confused_with', map['confused_with']);
          expectString('confusions[$i].difference', map['difference']);
          expectString(
            'confusions[$i].memory_trick',
            map['memory_trick'],
            nullable: true,
          );
        }
      }
    }
    if (raw.containsKey('exercises')) {
      final list = expectList(
        'exercises',
        raw['exercises'],
        min: minExerciseCount,
        max: authoredExerciseCount,
      );
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          _validateExercise(
            list[i],
            'exercises[$i]',
            fail,
            expectString,
            expectInt,
            expectList,
            expectMap,
            expectEnum,
          );
        }
      }
    }
    if (raw.containsKey('readings')) {
      final list = expectList('readings', raw['readings'], min: 3, max: 3);
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final map = expectMap('readings[$i]', list[i]);
          if (map == null) continue;
          const keys = {
            'position',
            'scene',
            'conversation_type',
            'title',
            'body',
            'before_phrase',
            'after_phrase',
          };
          _requireExactly(map, keys, 'readings[$i]', fail);
          expectInt('readings[$i].position', map['position'], min: 1, max: 3);
          expectEnum('readings[$i].scene', map['scene'], _scenes);
          expectEnum(
            'readings[$i].conversation_type',
            map['conversation_type'],
            _conversationTypes,
          );
          expectString('readings[$i].title', map['title']);
          expectString('readings[$i].body', map['body']);
          expectString('readings[$i].before_phrase', map['before_phrase']);
          expectString('readings[$i].after_phrase', map['after_phrase']);
        }
      }
    }
    if (raw['metrics'] != null) {
      final map = expectMap('metrics', raw['metrics']);
      if (map != null) {
        _rejectUnknown(
          map,
          {
            'zipf_overall',
            'zipf_by_country',
            'dispersion_dp',
            'pedantry_proxy',
            'family_size',
            'metrics_pending',
          },
          'metrics',
          fail,
        );
      }
    }
    if (raw['provenance'] != null) {
      final map = expectMap('provenance', raw['provenance']);
      if (map != null) {
        _rejectUnknown(
          map,
          {'generator', 'gate', 'checked_on'},
          'provenance',
          fail,
        );
      }
    }
    return issues;
  }

  void _validateExercise(
    Object? node,
    String where,
    void Function(String, String) fail,
    void Function(String, Object?, {bool nullable}) expectString,
    void Function(String, Object?, {int? min, int? max}) expectInt,
    List<Object?>? Function(String, Object?, {int? min, int? max}) expectList,
    Map<String, Object?>? Function(String, Object?) expectMap,
    void Function(String, Object?, Set<String>) expectEnum,
  ) {
    final map = expectMap(where, node);
    if (map == null) return;
    _requireKeys(
      map,
      {'position', 'sentence', 'hint_general', 'explanation', 'options'},
      where,
      fail,
    );
    _rejectUnknown(
      map,
      {'id', 'position', 'sentence', 'hint_general', 'explanation', 'options'},
      where,
      fail,
    );
    expectInt('$where.position', map['position'], min: 1, max: 8);
    expectString('$where.sentence', map['sentence']);
    expectString('$where.hint_general', map['hint_general']);
    expectString('$where.explanation', map['explanation']);
    final options = expectList(
      '$where.options',
      map['options'],
      min: 3,
      max: 3,
    );
    if (options == null) return;
    for (var i = 0; i < options.length; i++) {
      final option = expectMap('$where.options[$i]', options[i]);
      if (option == null) continue;
      _requireKeys(
        option,
        {'position', 'text', 'is_correct'},
        '$where.options[$i]',
        fail,
      );
      _rejectUnknown(
        option,
        {
          'position',
          'text',
          'is_correct',
          'distractor_type',
          'why_not',
          'hint_specific',
        },
        '$where.options[$i]',
        fail,
      );
      expectInt(
        '$where.options[$i].position',
        option['position'],
        min: 1,
        max: 3,
      );
      expectString('$where.options[$i].text', option['text']);
      if (option['is_correct'] is! bool) {
        fail('$where.options[$i].is_correct', 'is_correct must be a boolean');
      }
      if (option['distractor_type'] != null) {
        expectEnum(
          '$where.options[$i].distractor_type',
          option['distractor_type'],
          _distractorTypes,
        );
      }
      expectString(
        '$where.options[$i].why_not',
        option['why_not'],
        nullable: true,
      );
      expectString(
        '$where.options[$i].hint_specific',
        option['hint_specific'],
        nullable: true,
      );
    }
  }

  void _requireKeys(
    Map<String, Object?> map,
    Set<String> keys,
    String where,
    void Function(String, String) fail,
  ) {
    for (final key in keys) {
      if (!map.containsKey(key)) {
        fail('$where.$key', 'missing required key "$key"');
      }
    }
  }

  void _rejectUnknown(
    Map<String, Object?> map,
    Set<String> allowed,
    String where,
    void Function(String, String) fail,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) fail('$where.$key', 'unknown key "$key"');
    }
  }

  void _requireExactly(
    Map<String, Object?> map,
    Set<String> keys,
    String where,
    void Function(String, String) fail,
  ) {
    _requireKeys(map, keys, where, fail);
    _rejectUnknown(map, keys, where, fail);
  }
}
