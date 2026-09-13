/// Pure-Dart reader for `supabase/seed.sql`.
///
/// A port of `app/tool/seed/seed_parser.dart`'s row reader, without the Flutter
/// domain types: the content toolkit is a plain Dart package and cannot import
/// `package:flui`. `test/sql/round_trip_test.dart` proves both readers see the
/// same rows by emitting bytes that are identical to the checked-in seed.
library;

enum _Kind { word, string, number, symbol }

final class _Token {
  const _Token(this.kind, this.text);

  final _Kind kind;
  final String text;

  bool isWord(String value) =>
      kind == _Kind.word && text.toLowerCase() == value;

  bool isSymbol(String value) => kind == _Kind.symbol && text == value;
}

/// Rows of the seed by table name, without the `public.` prefix.
Map<String, List<Map<String, Object?>>> parseSeedRows(String sql) =>
    _Parser(_tokenize(sql)).parse();

List<_Token> _tokenize(String sql) {
  final tokens = <_Token>[];
  var i = 0;
  final wordChar = RegExp('[A-Za-z0-9_.]');
  final digit = RegExp('[0-9]');
  final digitOrMinus = RegExp('[0-9-]');
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
    } else if (digitOrMinus.hasMatch(c) &&
        digit.hasMatch(sql[c == '-' ? i + 1 : i])) {
      final start = i;
      i++;
      while (i < sql.length && digit.hasMatch(sql[i])) {
        i++;
      }
      tokens.add(_Token(_Kind.number, sql.substring(start, i)));
    } else if (wordChar.hasMatch(c)) {
      final start = i;
      while (i < sql.length && wordChar.hasMatch(sql[i])) {
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
  _Parser(this.tokens);

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
    if (_done || !_peek.isWord('values')) return;
    _i++;
    for (final tuple in _parseTuples()) {
      final row = Map<String, Object?>.fromIterables(columns, tuple);
      _rows.putIfAbsent(table, () => []).add(row);
      if (table == 'exercises') _lastExerciseId = row['id'] as String?;
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
        ...Map<String, Object?>.fromIterables(columns, tuple),
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
