import 'dart:convert';

import 'package:flui/features/reading/domain/reading.dart';
import 'package:flui/features/vocabulary/domain/exercises/cloze_exercise.dart';
import 'package:flui/features/vocabulary/domain/word.dart';

/// Rows of `supabase/seed.sql` by table name (without `public.`).
///
/// Understands the statements the seed uses: `insert into ... values`, the
/// `with exercise as (insert ...) insert into exercise_options ... cross join
/// (values ...) as o (...)` pattern, string literals with `''` escapes,
/// `array[...]` literals, `::type` casts, numbers, booleans and null.
Map<String, List<Map<String, Object?>>> parseSeedRows(String sql) {
  final parser = _Parser(_tokenize(sql));
  return parser.parse();
}

/// Word slug to the theme slugs it is tagged with, in seed order.
///
/// `content:emit` owns these links (see content/README.md), so this is the
/// only honest source for the fake backend's theme map.
Map<String, List<String>> parseSeedWordThemeSlugs(String sql) {
  final links = <String, List<String>>{};
  for (final row
      in parseSeedRows(sql)['word_themes'] ?? const <Map<String, Object?>>[]) {
    links
        .putIfAbsent(row['word_slug']! as String, () => [])
        .add(row['theme_slug']! as String);
  }
  return links;
}

/// Published words of the seed with their confusions, exercises and readings,
/// ordered by `sort_order`. Generated ids: `<exercise>:o<position>` for
/// options, `<word>:r<position>` for readings, `<word>:c<n>` for confusions.
List<Word> parseSeedWords(String sql) {
  final rows = parseSeedRows(sql);
  final optionsByExercise = <String, List<ExerciseOption>>{};
  for (final row
      in rows['exercise_options'] ?? const <Map<String, Object?>>[]) {
    final exerciseId = row['exercise_id']! as String;
    final position = row['position']! as int;
    optionsByExercise
        .putIfAbsent(exerciseId, () => [])
        .add(
          ExerciseOption(
            id: '$exerciseId:o$position',
            text: row['text']! as String,
            isCorrect: row['is_correct']! as bool,
            position: position,
            distractorType: switch (row['distractor_type']) {
              'paronym' => DistractorType.paronym,
              'near_synonym' => DistractorType.nearSynonym,
              'register' => DistractorType.register,
              _ => null,
            },
            whyNot: row['why_not'] as String?,
            hintSpecific: row['hint_specific'] as String?,
          ),
        );
  }

  List<Map<String, Object?>> childrenOf(String table, String wordId) =>
      [
        for (final row in rows[table] ?? const <Map<String, Object?>>[])
          if (row['word_id'] == wordId) row,
      ]..sort(
        (a, b) => ((a['position'] as int?) ?? 0).compareTo(
          (b['position'] as int?) ?? 0,
        ),
      );

  final words = <Word>[];
  for (final row in rows['words'] ?? const <Map<String, Object?>>[]) {
    if (row['published'] != true) continue;
    final id = row['id']! as String;
    final confusions = [
      for (final (index, c)
          in (rows['word_confusions'] ?? const <Map<String, Object?>>[])
              .where((c) => c['word_id'] == id)
              .indexed)
        WordConfusion(
          id: '$id:c${index + 1}',
          wordId: id,
          confusedWith: c['confused_with']! as String,
          confusedWordId: c['confused_word_id'] as String?,
          difference: c['difference']! as String,
          memoryTrick: c['memory_trick'] as String?,
        ),
    ];
    final replaces = (jsonDecode(row['replaces']! as String) as List<Object?>)
        .cast<Map<String, Object?>>();
    words.add(
      Word(
        id: id,
        slug: row['slug']! as String,
        lemma: row['lemma']! as String,
        partOfSpeech: PartOfSpeech.values.byName(
          row['part_of_speech']! as String,
        ),
        syllables: (row['syllables']! as List<Object?>).cast<String>(),
        stressedSyllable: row['stressed_syllable']! as int,
        ipaLatam: row['ipa_latam'] as String?,
        ipaEs: row['ipa_es'] as String?,
        explanation: row['explanation']! as String,
        exampleSentence: row['example_sentence']! as String,
        register: WordRegister.values.byName(row['register']! as String),
        pedantryRisk: row['pedantry_risk']! as int,
        usageTip: row['usage_tip'] as String?,
        whenNotToUse: row['when_not_to_use'] as String?,
        collocations: (row['collocations']! as List<Object?>).cast<String>(),
        replaces: [
          for (final pair in replaces)
            Replacement(
              before: pair['before']! as String,
              after: pair['after']! as String,
            ),
        ],
        family: (row['family']! as List<Object?>).cast<String>(),
        sortOrder: row['sort_order']! as int,
        confusions: confusions,
        exercises: [
          for (final e in childrenOf('exercises', id))
            ClozeExercise(
              id: e['id']! as String,
              wordId: id,
              sentence: e['sentence']! as String,
              hintGeneral: e['hint_general']! as String,
              explanation: e['explanation']! as String,
              position: e['position']! as int,
              options: (optionsByExercise[e['id']] ?? [])
                ..sort((a, b) => a.position.compareTo(b.position)),
            ),
        ],
        readings: [
          for (final r in childrenOf('readings', id))
            Reading(
              id: '$id:r${r['position']}',
              wordId: id,
              scene: Scene.values.byName(r['scene']! as String),
              conversationType: ConversationType.values.byName(
                r['conversation_type']! as String,
              ),
              title: r['title']! as String,
              body: r['body']! as String,
              beforePhrase: r['before_phrase']! as String,
              afterPhrase: r['after_phrase']! as String,
              position: r['position']! as int,
            ),
        ],
      ),
    );
  }
  return words..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

enum _Kind { word, string, number, symbol }

final class _Token {
  const new(this.kind, this.text);

  final _Kind kind;
  final String text;

  bool isWord(String value) =>
      kind == _Kind.word && text.toLowerCase() == value;

  bool isSymbol(String value) => kind == _Kind.symbol && text == value;
}

List<_Token> _tokenize(String sql) {
  final tokens = <_Token>[];
  var i = 0;
  bool isWordChar(String c) => RegExp('[A-Za-z0-9_.]').hasMatch(c);
  while (i < sql.length) {
    final c = sql[i];
    if (c.trim().isEmpty) {
      i++;
    } else if (sql.startsWith('--', i)) {
      final end = sql.indexOf('\n', i);
      i = end < 0 ? sql.length : end;
    } else if (c == "'") {
      final buffer = StringBuffer();
      i++;
      while (i < sql.length) {
        if (sql[i] == "'") {
          if (i + 1 < sql.length && sql[i + 1] == "'") {
            buffer.write("'");
            i += 2;
            continue;
          }
          i++;
          break;
        }
        buffer.write(sql[i]);
        i++;
      }
      tokens.add(_Token(_Kind.string, buffer.toString()));
    } else if (sql.startsWith('::', i)) {
      tokens.add(const _Token(_Kind.symbol, '::'));
      i += 2;
    } else if (RegExp('[0-9-]').hasMatch(c) &&
        RegExp('[0-9]').hasMatch(sql[c == '-' ? i + 1 : i])) {
      final start = i;
      i++;
      while (i < sql.length && RegExp('[0-9]').hasMatch(sql[i])) {
        i++;
      }
      tokens.add(_Token(_Kind.number, sql.substring(start, i)));
    } else if (isWordChar(c)) {
      final start = i;
      while (i < sql.length && isWordChar(sql[i])) {
        i++;
      }
      tokens.add(_Token(_Kind.word, sql.substring(start, i)));
    } else {
      tokens.add(_Token(_Kind.symbol, c));
      i++;
    }
  }
  return tokens;
}

final class _Parser {
  new(this.tokens);

  final List<_Token> tokens;
  var _i = 0;
  final _rows = <String, List<Map<String, Object?>>>{};
  String? _lastExerciseId;

  _Token get _peek => tokens[_i];

  bool get _done => _i >= tokens.length;

  Map<String, List<Map<String, Object?>>> parse() {
    while (!_done) {
      if (_peek.isWord('insert') &&
          _i + 2 < tokens.length &&
          tokens[_i + 1].isWord('into')) {
        _parseInsert();
      } else if (_peek.isWord('cross') &&
          _i + 3 < tokens.length &&
          tokens[_i + 1].isWord('join') &&
          tokens[_i + 2].isSymbol('(') &&
          tokens[_i + 3].isWord('values')) {
        _parseCrossJoinValues();
      } else {
        _i++;
      }
    }
    return _rows;
  }

  void _parseInsert() {
    _i += 2;
    final table = _peek.text.replaceFirst('public.', '');
    _i++;
    final columns = _parseColumns();
    if (!_done && _peek.isWord('select')) {
      _parseSelectFromValues(table);
      return;
    }
    if (!(!_done && _peek.isWord('values'))) return;
    _i++;
    for (final tuple in _parseTuples()) {
      final row = Map.fromIterables(columns, tuple);
      _rows.putIfAbsent(table, () => []).add(row);
      if (table == 'exercises') _lastExerciseId = row['id'] as String?;
    }
  }

  /// `insert into t (…) select … from (values (…), (…)) as v (a, b) join …`
  ///
  /// The emitter writes `word_themes` this way so the seed never repeats a
  /// theme uuid: the rows carry slugs and the joins resolve them. The row this
  /// records is therefore the `values` tuple — `word_slug`, `theme_slug`,
  /// `relevance` — not the columns the insert names.
  void _parseSelectFromValues(String table) {
    // Look ahead without consuming: `insert into exercise_options … select …
    // cross join (values …)` is also a select, and that one belongs to
    // _parseCrossJoinValues. Bailing out without moving _i leaves the main
    // loop free to recognise it.
    for (var j = _i; j + 3 < tokens.length; j++) {
      if (tokens[j].isSymbol(';')) return;
      if (tokens[j].isWord('cross') &&
          tokens[j + 1].isWord('join') &&
          tokens[j + 2].isSymbol('(') &&
          tokens[j + 3].isWord('values')) {
        return;
      }
      if (!tokens[j].isWord('from') ||
          !tokens[j + 1].isSymbol('(') ||
          !tokens[j + 2].isWord('values')) {
        continue;
      }
      _i = j + 3;
      final tuples = _parseTuples();
      _expectSymbol(')');
      if (!_done && _peek.isWord('as')) _i += 2;
      final columns = _parseColumns();
      for (final tuple in tuples) {
        _rows
            .putIfAbsent(table, () => [])
            .add(Map.fromIterables(columns, tuple));
      }
      return;
    }
  }

  void _parseCrossJoinValues() {
    _i += 4;
    final tuples = _parseTuples();
    _expectSymbol(')');
    if (_peek.isWord('as')) _i += 2;
    final columns = _parseColumns();
    for (final tuple in tuples) {
      _rows.putIfAbsent('exercise_options', () => []).add({
        'exercise_id': _lastExerciseId,
        ...Map.fromIterables(columns, tuple),
      });
    }
  }

  List<String> _parseColumns() {
    _expectSymbol('(');
    final columns = <String>[];
    while (!_peek.isSymbol(')')) {
      if (_peek.kind == _Kind.word) columns.add(_peek.text);
      _i++;
    }
    _i++;
    return columns;
  }

  List<List<Object?>> _parseTuples() {
    final tuples = <List<Object?>>[];
    do {
      if (_peek.isSymbol(',')) _i++;
      _expectSymbol('(');
      final values = <Object?>[];
      while (!_peek.isSymbol(')')) {
        values.add(_parseExpression());
        if (_peek.isSymbol(',')) _i++;
      }
      _i++;
      tuples.add(values);
    } while (!_done && _peek.isSymbol(',') && _isTupleAhead());
    return tuples;
  }

  bool _isTupleAhead() =>
      _i + 1 < tokens.length && tokens[_i + 1].isSymbol('(');

  Object? _parseExpression() {
    final token = _peek;
    Object? value;
    if (token.kind == _Kind.string) {
      value = token.text;
      _i++;
    } else if (token.kind == _Kind.number) {
      value = int.parse(token.text);
      _i++;
    } else if (token.isWord('null')) {
      _i++;
    } else if (token.isWord('true') || token.isWord('false')) {
      value = token.isWord('true');
      _i++;
    } else if (token.isWord('array')) {
      _i++;
      _expectSymbol('[');
      final items = <Object?>[];
      while (!_peek.isSymbol(']')) {
        items.add(_parseExpression());
        if (_peek.isSymbol(',')) _i++;
      }
      _i++;
      value = items;
    } else {
      throw FormatException('Unexpected token ${token.text}');
    }
    // Casts: ::jsonb, ::text[]
    while (!_done && _peek.isSymbol('::')) {
      _i += 2;
      if (!_done && _peek.isSymbol('[')) _i += 2;
    }
    return value;
  }

  void _expectSymbol(String symbol) {
    if (!_peek.isSymbol(symbol)) {
      throw FormatException('Expected $symbol, found ${_peek.text}');
    }
    _i++;
  }
}
