import 'dart:convert';

/// Canonical key order of a challenge file. Mirrors `word_yaml.dart`'s
/// `wordKeyOrder`; emitting in this order keeps diffs small and keeps
/// generated files identical between runs.
const challengeKeyOrder = <String>[
  'slug',
  'status',
  'purpose',
  'diagnosis_slot',
  'skill',
  'mode',
  'difficulty',
  'prompt',
  'cue',
  'focus',
  'focus_behaviors',
  'transfer_prompts',
  'target_seconds',
];

/// YAML text for one challenge map. Every string is double quoted like
/// `writeWordYaml`, so Spanish punctuation, « » and colons never need
/// special handling.
///
/// Unlike a word, every challenge field is a scalar or a flat string list —
/// there is no nested map or list-of-maps — so this writer needs none of
/// `word_yaml.dart`'s recursive map machinery.
String writeChallengeYaml(Map<String, Object?> challenge, {String? header}) {
  final buffer = StringBuffer();
  if (header != null) {
    for (final line in header.trimRight().split('\n')) {
      buffer.writeln('# $line');
    }
  }
  final keys = [
    ...challengeKeyOrder.where(challenge.containsKey),
    ...challenge.keys.where((key) => !challengeKeyOrder.contains(key)),
  ];
  for (final key in keys) {
    final value = challenge[key];
    if (value is List) {
      if (value.isEmpty) {
        buffer.writeln('$key: []');
        continue;
      }
      buffer.writeln('$key:');
      for (final item in value) {
        buffer.writeln('  - ${_scalar(item)}');
      }
    } else {
      buffer.writeln('$key: ${_scalar(value)}');
    }
  }
  return buffer.toString();
}

String _scalar(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return '$value';
  return jsonEncode('$value');
}
