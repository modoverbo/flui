import 'dart:convert';

/// Canonical key order of a word file. Emitting in this order keeps diffs
/// small and keeps generated files identical between runs.
const wordKeyOrder = <String>[
  'schema_version',
  'id',
  'sort_order',
  'slug',
  'status',
  'lemma',
  'part_of_speech',
  'syllables',
  'stressed_syllable',
  'ipa_latam',
  'ipa_es',
  'explanation',
  'example_sentence',
  'register',
  'pedantry_risk',
  'usage_tip',
  'when_not_to_use',
  'collocations',
  'replaces',
  'family',
  'semantic_set_id',
  'themes',
  'tags',
  'confusions',
  'exercises',
  'readings',
  'metrics',
  'provenance',
];

const _exerciseKeyOrder = <String>[
  'id',
  'position',
  'sentence',
  'hint_general',
  'explanation',
  'options',
];

const _optionKeyOrder = <String>[
  'position',
  'text',
  'is_correct',
  'distractor_type',
  'why_not',
  'hint_specific',
];

const _readingKeyOrder = <String>[
  'position',
  'scene',
  'conversation_type',
  'title',
  'body',
  'before_phrase',
  'after_phrase',
];

const _keyOrders = <String, List<String>>{
  'exercises': _exerciseKeyOrder,
  'options': _optionKeyOrder,
  'readings': _readingKeyOrder,
  'replaces': ['before', 'after'],
  'themes': ['slug', 'relevance'],
  'confusions': ['confused_with', 'difference', 'memory_trick'],
  'tags': ['comodin', 'funcion', 'canal', 'formalidad', 'variedad'],
  'metrics': [
    'zipf_overall',
    'zipf_by_country',
    'dispersion_dp',
    'pedantry_proxy',
    'family_size',
    'metrics_pending',
  ],
  'provenance': ['generator', 'gate', 'checked_on'],
};

/// YAML text for one word map. Every string is double quoted, so Spanish
/// punctuation, « » and colons never need special handling.
String writeWordYaml(Map<String, Object?> word, {String? header}) {
  final buffer = StringBuffer();
  if (header != null) {
    for (final line in header.trimRight().split('\n')) {
      buffer.writeln('# $line');
    }
  }
  _writeMap(buffer, word, wordKeyOrder, 0);
  return buffer.toString();
}

void _writeMap(
  StringBuffer buffer,
  Map<String, Object?> map,
  List<String> order,
  int indent,
) {
  final pad = ' ' * indent;
  final keys = [
    ...order.where(map.containsKey),
    ...map.keys.where((key) => !order.contains(key)),
  ];
  for (final key in keys) {
    final value = map[key];
    if (value is Map<String, Object?>) {
      if (value.isEmpty) {
        buffer.writeln('$pad$key: {}');
        continue;
      }
      buffer.writeln('$pad$key:');
      _writeMap(buffer, value, _keyOrders[key] ?? const [], indent + 2);
    } else if (value is List) {
      if (value.isEmpty) {
        buffer.writeln('$pad$key: []');
        continue;
      }
      buffer.writeln('$pad$key:');
      for (final item in value) {
        if (item is Map<String, Object?>) {
          final itemOrder = _keyOrders[key] ?? const <String>[];
          final lines = StringBuffer();
          _writeMap(lines, item, itemOrder, indent + 4);
          final rendered = lines.toString().split('\n')..removeLast();
          buffer.writeln('$pad  - ${rendered.first.trimLeft()}');
          for (final line in rendered.skip(1)) {
            buffer.writeln(line);
          }
        } else {
          buffer.writeln('$pad  - ${_scalar(item)}');
        }
      }
    } else {
      buffer.writeln('$pad$key: ${_scalar(value)}');
    }
  }
}

String _scalar(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return '$value';
  return jsonEncode('$value');
}
