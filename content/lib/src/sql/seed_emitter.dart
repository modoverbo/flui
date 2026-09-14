import 'dart:convert';

import 'package:content/src/model/theme.dart';
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
/// `app/tool/seed/seed_parser.dart` reads only `words`, `word_confusions`,
/// `exercises`, `exercise_options` and `readings`, so the `word_themes` block
/// is invisible to the generated fixture.
///
/// [taxonomy] is optional and off by default: the 16 theme rows are currently
/// owned by `supabase/seed_themes.sql`, and emitting them here as well would
/// insert the same rows twice. Pass it only once that file has been reduced to
/// nothing (see README, "Who owns the theme rows").
String emitWords(List<Word> words, {ThemeTaxonomy? taxonomy}) {
  final buffer = StringBuffer();
  final sortOrders = sortOrdersFor(words);
  if (taxonomy != null) buffer.write(_emitThemes(taxonomy));
  for (var index = 0; index < words.length; index++) {
    final word = words[index];
    final wordId = word.id ?? deterministicWordId(word.slug);
    final sortOrder = sortOrders[index];
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
      ..writeln('   semantic_set_id, sort_order, published)')
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
      ..writeln('  ${sqlLiteral(word.semanticSetId)},')
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
  buffer.write(_emitWordThemes(words));
  return buffer.toString();
}

/// The taxonomy rows, when the emitter owns them.
String _emitThemes(ThemeTaxonomy taxonomy) {
  final themes = [...taxonomy.themes]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final buffer = StringBuffer()
    ..writeln(_rule)
    ..writeln('-- Themes (content/themes.yml)')
    ..writeln(_rule)
    ..writeln()
    ..writeln('insert into public.themes')
    ..writeln(
      '  (slug, family, name, tagline, jtbd, content_type, sort_order, published)',
    )
    ..writeln('values');
  for (var i = 0; i < themes.length; i++) {
    final theme = themes[i];
    final end = i == themes.length - 1 ? '' : ',';
    buffer
      ..writeln(
        '  (${sqlLiteral(theme.slug)}, ${sqlLiteral(theme.family)}, ${sqlLiteral(theme.name)},',
      )
      ..writeln('   ${sqlLiteral(theme.tagline)},')
      ..writeln('   ${sqlLiteral(theme.jtbd)},')
      ..writeln(
        '   ${sqlLiteral(theme.contentType)}, ${theme.sortOrder}, true)$end',
      );
  }
  buffer
    ..writeln('on conflict (slug) do update')
    ..writeln('  set family = excluded.family,')
    ..writeln('      name = excluded.name,')
    ..writeln('      tagline = excluded.tagline,')
    ..writeln('      jtbd = excluded.jtbd,')
    ..writeln('      content_type = excluded.content_type,')
    ..writeln('      sort_order = excluded.sort_order,')
    ..writeln('      published = excluded.published;')
    ..writeln();
  return buffer.toString();
}

/// The word -> theme links, resolved by slug so the emitter never repeats the
/// theme uuids that `supabase/seed_themes.sql` assigns.
String _emitWordThemes(List<Word> words) {
  final links = <(String, String, int)>[
    for (final word in words)
      for (final theme in word.themes) (word.slug, theme.slug, theme.relevance),
  ];
  if (links.isEmpty) return '';

  final buffer = StringBuffer()
    ..writeln()
    ..writeln(_rule)
    ..writeln('-- Word themes (content/words/<slug>.yml)')
    ..writeln(_rule)
    ..writeln()
    ..writeln(
      'insert into public.word_themes (word_id, theme_id, relevance, sort_order)',
    )
    ..writeln('select w.id, t.id, v.relevance, w.sort_order')
    ..writeln('from (values');
  for (var i = 0; i < links.length; i++) {
    final (slug, theme, relevance) = links[i];
    final end = i == links.length - 1 ? '' : ',';
    buffer.writeln(
      '  (${sqlLiteral(slug)}, ${sqlLiteral(theme)}, $relevance)$end',
    );
  }
  buffer
    ..writeln(') as v (word_slug, theme_slug, relevance)')
    ..writeln('join public.words w on w.slug = v.word_slug')
    ..writeln('join public.themes t on t.slug = v.theme_slug')
    ..writeln('on conflict (word_id, theme_id) do update')
    ..writeln('  set relevance = excluded.relevance,')
    ..writeln('      sort_order = excluded.sort_order;');
  return buffer.toString();
}

/// Full seed file: the preserved preamble plus the emitted word section.
String emitSeed({
  required String preamble,
  required List<Word> words,
  ThemeTaxonomy? taxonomy,
}) => '$preamble${emitWords(words, taxonomy: taxonomy)}';

/// The `sort_order` to write for each of [words], already in emission order.
///
/// `sort_order` is the introduction order the session planner reads, so it has
/// to rise with the order the words are emitted in. An authored value is kept
/// — the catalog numbers its words in batches and that is information — and a
/// word without one continues past the highest authored value instead of
/// restarting at 1, which would file it ahead of every batch.
List<int> sortOrdersFor(List<Word> words) {
  var next = 0;
  for (final word in words) {
    if (word.sortOrder != null && word.sortOrder! > next) next = word.sortOrder!;
  }
  return [
    for (final word in words)
      if (word.sortOrder case final authored?) authored else ++next,
  ];
}

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
