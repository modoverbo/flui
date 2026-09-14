import 'dart:convert';
import 'dart:io';

import 'package:content/src/text/spanish_text.dart';

/// The lexical categories the pool cares about.
enum LexicalCategory { noun, verb, adjective, adverb, other }

/// Wikidata QIDs for the categories above.
const _categoryByQid = <String, LexicalCategory>{
  'Q1084': LexicalCategory.noun,
  'Q24905': LexicalCategory.verb,
  'Q34698': LexicalCategory.adjective,
  'Q380057': LexicalCategory.adverb,
};

const _partOfSpeechByCategory = <LexicalCategory, String>{
  LexicalCategory.noun: 'sustantivo',
  LexicalCategory.verb: 'verbo',
  LexicalCategory.adjective: 'adjetivo',
  LexicalCategory.adverb: 'adverbio',
};

/// A permissively licensed Spanish word list.
///
/// The pool uses it as a hard gate: a form the dictionary does not attest is
/// corpus noise (OCR, a foreign word, a typo) and is dropped before scoring,
/// never scored and ranked. It also supplies a real part of speech, which is a
/// fact where the morphology guess in `metrics.dart` is only a guess.
final class SpanishLexicon {
  const SpanishLexicon(this._byLemma);

  /// Folded lemma to the categories the dictionary gives it.
  final Map<String, Set<LexicalCategory>> _byLemma;

  int get length => _byLemma.length;

  bool get isEmpty => _byLemma.isEmpty;

  bool get isNotEmpty => _byLemma.isNotEmpty;

  bool contains(String lemma) => _byLemma.containsKey(foldForComparison(lemma));

  Set<LexicalCategory> categoriesOf(String lemma) =>
      _byLemma[foldForComparison(lemma)] ?? const {};

  bool isNoun(String lemma) =>
      categoriesOf(lemma).contains(LexicalCategory.noun);

  bool isVerb(String lemma) =>
      categoriesOf(lemma).contains(LexicalCategory.verb);

  /// The catalog's part-of-speech name, or null when the dictionary has no
  /// opinion. Verb wins over noun when a form is both, because a verb lemma is
  /// what the exercise bank conjugates.
  String? partOfSpeechFor(String lemma) {
    final categories = categoriesOf(lemma);
    if (categories.isEmpty) return null;
    for (final category in [
      LexicalCategory.verb,
      LexicalCategory.adjective,
      LexicalCategory.adverb,
      LexicalCategory.noun,
    ]) {
      if (categories.contains(category)) {
        return _partOfSpeechByCategory[category];
      }
    }
    return null;
  }

  /// The shipped format: `# comment` lines, then `lemma\tcategory,category`.
  String toTsv() {
    final buffer = StringBuffer()
      ..writeln('# Spanish lexeme lemmas from Wikidata Lexemes.')
      ..writeln('# Licence: CC0 1.0 Universal (public domain dedication).')
      ..writeln(
        '# Source: https://query.wikidata.org/sparql (dct:language wd:Q1321)',
      )
      ..writeln('# Built by: dart run content:corpus. See LICENSES.md.')
      ..writeln('# Format: folded lemma <TAB> comma-separated categories.');
    final lemmas = _byLemma.keys.toList()..sort();
    for (final lemma in lemmas) {
      final categories = _byLemma[lemma]!.map((c) => c.name).toList()..sort();
      buffer.writeln('$lemma\t${categories.join(',')}');
    }
    return buffer.toString();
  }
}

/// Reads the TSV the Wikidata Query Service returns for the lexeme query.
SpanishLexicon parseWikidataLexemes(String tsv) {
  final byLemma = <String, Set<LexicalCategory>>{};
  for (final line in const LineSplitter().convert(tsv)) {
    if (line.isEmpty || line.startsWith('?') || line.startsWith('#')) continue;
    final parts = line.split('\t');
    if (parts.length < 2) continue;
    final lemma = _unquote(parts[0]);
    if (lemma.isEmpty) continue;
    final qid = parts[1].split('/').last.replaceAll('>', '').trim();
    byLemma
        .putIfAbsent(foldForComparison(lemma), () => <LexicalCategory>{})
        .add(_categoryByQid[qid] ?? LexicalCategory.other);
  }
  return SpanishLexicon(byLemma);
}

/// Reads the file `content:corpus` writes with [SpanishLexicon.toTsv].
SpanishLexicon parseShippedLexicon(String tsv) {
  final byLemma = <String, Set<LexicalCategory>>{};
  for (final line in const LineSplitter().convert(tsv)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('\t');
    if (parts.length < 2) continue;
    byLemma[parts[0]] = {
      for (final name in parts[1].split(','))
        LexicalCategory.values.firstWhere(
          (c) => c.name == name,
          orElse: () => LexicalCategory.other,
        ),
    };
  }
  return SpanishLexicon(byLemma);
}

/// Any RDF language tag, not only `@es`: Wikidata also carries regional
/// variants such as `"platicar"@es-mx` and `"sancochar"@es-419`.
final _languageTag = RegExp(r'@[A-Za-z0-9-]+$');

String _unquote(String value) {
  var text = value.trim().replaceFirst(_languageTag, '');
  if (text.startsWith('"') && text.endsWith('"') && text.length >= 2) {
    text = text.substring(1, text.length - 1);
  }
  return text;
}

/// Fetches the Spanish lexeme list. Injectable so tests stay offline.
// A single-method interface on purpose: it is the seam that keeps the tests
// off the network.
// ignore: one_member_abstracts
abstract interface class LexiconSource {
  Future<SpanishLexicon> fetch();
}

/// Reads the list from a file that `content:corpus` already wrote.
final class CachedLexiconSource implements LexiconSource {
  const CachedLexiconSource(this.path);

  final String path;

  @override
  Future<SpanishLexicon> fetch() async {
    final file = File(path);
    if (!file.existsSync()) return const SpanishLexicon({});
    return parseShippedLexicon(file.readAsStringSync());
  }
}

/// Queries the Wikidata Query Service. The result is CC0.
final class WikidataLexiconSource implements LexiconSource {
  WikidataLexiconSource({this.log});

  static const query =
      'SELECT ?lemma ?cat WHERE { ?l dct:language wd:Q1321 ; '
      'wikibase:lemma ?lemma ; wikibase:lexicalCategory ?cat . }';

  final void Function(String message)? log;
  final HttpClient _client = HttpClient();

  @override
  Future<SpanishLexicon> fetch() async {
    log?.call('querying Wikidata for Spanish lexemes (CC0)');
    final uri = Uri.https('query.wikidata.org', '/sparql', {'query': query});
    final request = await _client.getUrl(uri);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'text/tab-separated-values')
      ..set(HttpHeaders.userAgentHeader, 'flui-content/0.1');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('Wikidata returned ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    return parseWikidataLexemes(body);
  }
}
