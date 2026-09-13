import 'dart:convert';

import 'package:content/src/model/word.dart';
import 'package:crypto/crypto.dart';

/// Everything of `supabase/seed.sql` before the first word block. It is kept
/// verbatim in `content/templates/seed_preamble.sql` so the emitted file keeps
/// the subscription plans and the file header the seed already had.
const wordSectionMarker = '\n$_rule\n-- 1. ';

const _rule =
    '-- ----------------------------------------------------------------------------';

/// Splits a seed file into its preamble and its word section.
({String preamble, String words}) splitSeed(String sql) {
  final index = sql.indexOf(wordSectionMarker);
  if (index < 0) {
    throw const FormatException('the seed has no "-- 1. <slug>" word section');
  }
  return (
    preamble: sql.substring(0, index + 1),
    words: sql.substring(index + 1),
  );
}

/// Deterministic identity for a word that has none yet: a UUIDv5-shaped value
/// derived from the slug, so emitting twice never changes the file.
String deterministicWordId(String slug) => _uuidFrom('flui.word:$slug');

String deterministicExerciseId(String slug, int position) =>
    _uuidFrom('flui.exercise:$slug:$position');

String _uuidFrom(String seed) {
  final bytes = sha1.convert(utf8.encode(seed)).bytes.sublist(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4 shape
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  String hex(int from, int to) => [
    for (var i = from; i < to; i++) bytes[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// SQL string literal, or `null`.
String sqlLiteral(String? value) =>
    value == null ? 'null' : "'${value.replaceAll("'", "''")}'";

String _sqlArray(List<String> items) =>
    "array[${items.map(sqlLiteral).join(', ')}]::text[]";

String _replacesJson(List<Replacement> replaces) {
  final parts = [
    for (final pair in replaces)
      '{"before": ${jsonEncode(pair.before)}, "after": ${jsonEncode(pair.after)}}',
  ];
  return "${sqlLiteral('[${parts.join(', ')}]')}::jsonb";
}

/// Renders the word section of `supabase/seed.sql`.
///
/// Byte-for-byte compatible with the checked-in seed, so
/// `app/tool/seed/seed_parser.dart` and the generated fixture never move.
String emitWords(List<Word> words) {
  final buffer = StringBuffer();
  for (var index = 0; index < words.length; index++) {
    final word = words[index];
    final wordId = word.id ?? deterministicWordId(word.slug);
    final sortOrder = word.sortOrder ?? index + 1;
    if (index > 0) buffer.writeln();
    buffer
      ..writeln(_rule)
      ..writeln('-- ${index + 1}. ${word.slug}')
      ..writeln(_rule)
      ..writeln()
      ..writeln('insert into public.words')
      ..writeln(
        '  (id, slug, lemma, part_of_speech, syllables, stressed_syllable, ipa_latam, ipa_es, explanation,',
      )
      ..writeln(
        '   example_sentence, register, pedantry_risk, usage_tip, when_not_to_use, collocations, replaces, family,',
      )
      ..writeln('   sort_order, published)')
      ..writeln('values (')
      ..writeln('  ${sqlLiteral(wordId)},')
      ..writeln('  ${sqlLiteral(word.slug)},')
      ..writeln('  ${sqlLiteral(word.lemma)},')
      ..writeln('  ${sqlLiteral(word.partOfSpeech.name)},')
      ..writeln('  ${_sqlArray(word.syllables)},')
      ..writeln('  ${word.stressedSyllable},')
      ..writeln('  ${sqlLiteral(word.ipaLatam)},')
      ..writeln('  ${sqlLiteral(word.ipaEs)},')
      ..writeln('  ${sqlLiteral(word.explanation)},')
      ..writeln('  ${sqlLiteral(word.exampleSentence)},')
      ..writeln('  ${sqlLiteral(word.register.name)},')
      ..writeln('  ${word.pedantryRisk},')
      ..writeln('  ${sqlLiteral(word.usageTip)},')
      ..writeln('  ${sqlLiteral(word.whenNotToUse)},')
      ..writeln('  ${_sqlArray(word.collocations)},')
      ..writeln('  ${_replacesJson(word.replaces)},')
      ..writeln('  ${_sqlArray(word.family)},')
      ..writeln('  $sortOrder,')
      ..writeln('  true')
      ..writeln(');')
      ..writeln()
      ..writeln(
        'insert into public.word_confusions (word_id, confused_with, difference, memory_trick)',
      )
      ..writeln('values');
    for (var i = 0; i < word.confusions.length; i++) {
      final confusion = word.confusions[i];
      final end = i == word.confusions.length - 1 ? ';' : ',';
      buffer.writeln(
        '  (${sqlLiteral(wordId)}, ${sqlLiteral(confusion.confusedWith)}, '
        '${sqlLiteral(confusion.difference)}, ${sqlLiteral(confusion.memoryTrick)})$end',
      );
    }

    for (final exercise in word.exercises) {
      final exerciseId =
          exercise.id ?? deterministicExerciseId(word.slug, exercise.position);
      buffer
        ..writeln()
        ..writeln('with exercise as (')
        ..writeln(
          '  insert into public.exercises (id, word_id, sentence, hint_general, explanation, position)',
        )
        ..writeln('  values (')
        ..writeln('    ${sqlLiteral(exerciseId)},')
        ..writeln('    ${sqlLiteral(wordId)},')
        ..writeln('    ${sqlLiteral(exercise.sentence)},')
        ..writeln('    ${sqlLiteral(exercise.hintGeneral)},')
        ..writeln('    ${sqlLiteral(exercise.explanation)},')
        ..writeln('    ${exercise.position}')
        ..writeln('  )')
        ..writeln('  returning id')
        ..writeln(')')
        ..writeln(
          'insert into public.exercise_options (exercise_id, text, is_correct, distractor_type, why_not, hint_specific, position)',
        )
        ..writeln(
          'select exercise.id, o.text, o.is_correct, o.distractor_type, o.why_not, o.hint_specific, o.position',
        )
        ..writeln('from exercise')
        ..writeln('cross join (values');
      final options = [...exercise.options]
        ..sort((a, b) => a.position.compareTo(b.position));
      for (var i = 0; i < options.length; i++) {
        final option = options[i];
        final end = i == options.length - 1 ? '' : ',';
        final type = option.distractorType == null
            ? 'null'
            : sqlLiteral(distractorTypeNames[option.distractorType]);
        buffer.writeln(
          '    (${sqlLiteral(option.text)}, ${option.isCorrect}, $type, '
          '${sqlLiteral(option.whyNot)}, ${sqlLiteral(option.hintSpecific)}, '
          '${option.position})$end',
        );
      }
      buffer.writeln(
        ') as o (text, is_correct, distractor_type, why_not, hint_specific, position);',
      );
    }

    buffer
      ..writeln()
      ..writeln(
        'insert into public.readings (word_id, scene, conversation_type, title, body, before_phrase, after_phrase, position)',
      )
      ..writeln('values');
    final readings = [...word.readings]
      ..sort((a, b) => a.position.compareTo(b.position));
    for (var i = 0; i < readings.length; i++) {
      final reading = readings[i];
      final end = i == readings.length - 1 ? ';' : ',';
      buffer
        ..writeln(
          '  (${sqlLiteral(wordId)}, ${sqlLiteral(reading.scene.name)}, '
          '${sqlLiteral(reading.conversationType.name)}, ${sqlLiteral(reading.title)},',
        )
        ..writeln('   ${sqlLiteral(reading.body)},')
        ..writeln(
          '   ${sqlLiteral(reading.beforePhrase)}, ${sqlLiteral(reading.afterPhrase)}, '
          '${reading.position})$end',
        );
    }
  }
  return buffer.toString();
}

/// Full seed file: the preserved preamble plus the emitted word section.
String emitSeed({required String preamble, required List<Word> words}) =>
    '$preamble${emitWords(words)}';

/// Words that reach the database, in a stable order: `sort_order`, then slug.
List<Word> approvedWordsInOrder(List<Word> words) {
  final approved =
      [
        for (final word in words)
          if (word.status == WordStatus.approved) word,
      ]..sort((a, b) {
        final bySortOrder = (a.sortOrder ?? 1 << 30).compareTo(
          b.sortOrder ?? 1 << 30,
        );
        return bySortOrder != 0 ? bySortOrder : a.slug.compareTo(b.slug);
      });
  return approved;
}
