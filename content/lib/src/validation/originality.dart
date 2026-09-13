import 'dart:convert';
import 'dart:io';

import 'package:content/src/model/word.dart';
import 'package:content/src/text/spanish_morphology.dart';
import 'package:content/src/text/spanish_text.dart';
import 'package:content/src/validation/context.dart';
import 'package:content/src/validation/issue.dart';
import 'package:content/src/validation/validator.dart';

/// One search result. Only the fields the probe reads.
final class SearchHit {
  const SearchHit({required this.url, required this.snippet});

  final String url;
  final String snippet;
}

/// Pluggable search backend, so tests never touch the network.
// A single-method interface on purpose: it is the seam that keeps the tests
// off the network.
// ignore: one_member_abstracts
abstract interface class SearchFetcher {
  Future<List<SearchHit>> search(String query);
}

/// The default: refuses to leave the machine.
final class OfflineFetcher implements SearchFetcher {
  const OfflineFetcher();

  @override
  Future<List<SearchHit>> search(String query) async => const [];
}

/// Best-effort HTML search, used only when the operator passes `--probe-rae`
/// and `--network`. It is deliberately slow and polite.
final class DuckDuckGoFetcher implements SearchFetcher {
  DuckDuckGoFetcher({this.delay = const Duration(seconds: 2)});

  final Duration delay;
  final HttpClient _client = HttpClient();

  @override
  Future<List<SearchHit>> search(String query) async {
    await Future<void>.delayed(delay);
    final uri = Uri.https('html.duckduckgo.com', '/html/', {'q': query});
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'flui-content-probe/0.1');
    final response = await request.close();
    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    final results = <SearchHit>[];
    for (final match in RegExp(
      '<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)</a>',
      dotAll: true,
    ).allMatches(body)) {
      results.add(
        SearchHit(
          url: match[1] ?? '',
          snippet: _stripTags(match[2] ?? ''),
        ),
      );
    }
    return results;
  }

  String _stripTags(String html) =>
      html.replaceAll(RegExp('<[^>]*>'), '').replaceAll('&amp;', '&');
}

/// Two distinctive 6-grams of a text, preferring the ones densest in content
/// words: a shared 6-gram of function words proves nothing.
List<String> sixGrams(String text) {
  final tokens = tokenizeWords(text);
  if (tokens.length < 6) return const [];
  final grams = <(String, int, int)>[];
  for (var i = 0; i + 6 <= tokens.length; i++) {
    final window = tokens.sublist(i, i + 6);
    final content = window
        .where((t) => !spanishFunctionWords.contains(foldForComparison(t)))
        .length;
    grams.add((window.join(' '), content, i));
  }
  grams.sort((a, b) {
    final byContent = b.$2.compareTo(a.$2);
    return byContent != 0 ? byContent : a.$3.compareTo(b.$3);
  });
  final picked = <String>[];
  for (final gram in grams) {
    if (picked.length == 2) break;
    // Keep the two picks apart so they are not near-identical windows.
    if (picked.isNotEmpty && (gram.$3 - grams.first.$3).abs() < 3) continue;
    picked.add(gram.$1);
  }
  if (picked.length < 2 && grams.length > 1) picked.add(grams[1].$1);
  return picked;
}

/// Async validator: the runner awaits it separately from the sync suite.
abstract class AsyncWordValidator extends ContentValidator {
  const AsyncWordValidator();

  Future<List<Issue>> validateWordAsync(Word word, LibraryContext context);
}

/// Originality probe against rae.es / dle.rae.es.
///
/// flui stores no RAE text, so a local 6-gram overlap check is impossible. The
/// probe instead asks a search engine, site restricted, whether a distinctive
/// 6-gram of our own prose already exists there. Opt-in (`--probe-rae`) and
/// injectable, so `dart test` never reaches the network.
final class RaeProbeValidator extends AsyncWordValidator {
  const RaeProbeValidator(this.fetcher);

  final SearchFetcher fetcher;

  static const siteFilter = 'site:rae.es OR site:dle.rae.es';

  @override
  String get code => 'rae_probe';

  @override
  String get description =>
      'distinctive 6-grams of explanation, usage_tip and when_not_to_use do not '
      'appear on rae.es (opt-in, --probe-rae)';

  @override
  Severity get severity => Severity.blocking;

  @override
  Future<List<Issue>> validateWordAsync(
    Word word,
    LibraryContext context,
  ) async {
    if (!context.options.probeRae) return const [];
    final fields = <String, String?>{
      'explanation': word.explanation,
      'usage_tip': word.usageTip,
      'when_not_to_use': word.whenNotToUse,
    };
    final issues = <Issue>[];
    for (final entry in fields.entries) {
      final text = entry.value;
      if (text == null || text.trim().isEmpty) continue;
      for (final gram in sixGrams(text)) {
        final hits = await fetcher.search('"$gram" $siteFilter');
        final folded = foldForComparison(gram);
        for (final hit in hits) {
          if (!foldForComparison(hit.snippet).contains(folded)) continue;
          issues.add(
            Issue(
              code: code,
              severity: severity,
              slug: word.slug,
              location: entry.key,
              message: 'the 6-gram "$gram" already appears at ${hit.url}',
            ),
          );
        }
      }
    }
    return issues;
  }
}
